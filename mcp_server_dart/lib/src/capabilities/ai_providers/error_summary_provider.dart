// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io' as io;

abstract interface class ErrorSummaryProvider {
  String get id;

  Future<String?> summarize({
    required final List<Map<String, Object?>> errors,
    required final List<Map<String, Object?>> causes,
  });
}

final class NoopErrorSummaryProvider implements ErrorSummaryProvider {
  const NoopErrorSummaryProvider();

  @override
  String get id => 'none';

  @override
  Future<String?> summarize({
    required final List<Map<String, Object?>> errors,
    required final List<Map<String, Object?>> causes,
  }) async => null;
}

// TODO(arenukvern): refactor - split provider and summarization
final class OpenAiErrorSummaryProvider implements ErrorSummaryProvider {
  OpenAiErrorSummaryProvider({
    final String? apiKey,
    final String model = 'gpt-5.4-mini',
    final Uri? endpoint,
    final Duration timeout = const Duration(seconds: 20),
  }) : _apiKey = apiKey ?? io.Platform.environment['OPENAI_API_KEY'] ?? '',
       _model = model,
       _endpoint = endpoint ?? Uri.parse('https://api.openai.com/v1/responses'),
       _timeout = timeout;

  final String _apiKey;
  final String _model;
  final Uri _endpoint;
  final Duration _timeout;

  @override
  String get id => 'openai';

  @override
  Future<String?> summarize({
    required final List<Map<String, Object?>> errors,
    required final List<Map<String, Object?>> causes,
  }) async {
    if (_apiKey.isEmpty) {
      return null;
    }

    final client = io.HttpClient();
    client.connectionTimeout = _timeout;

    final request = await client.postUrl(_endpoint);
    request.headers.set('Authorization', 'Bearer $_apiKey');
    request.headers.set('Content-Type', 'application/json');

    final payload = {
      'model': _model,
      'input': [
        {
          'role': 'system',
          'content':
              'You summarize Flutter runtime error diagnostics concisely. '
              'Only output 2-4 sentences with likely root cause and next step.',
        },
        {
          'role': 'user',
          'content': jsonEncode({'errors': errors, 'causes': causes}),
        },
      ],
      'max_output_tokens': 200,
    };

    request.write(jsonEncode(payload));

    final response = await request.close().timeout(_timeout);
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return null;
    }

    final outputText = decoded['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return outputText.trim();
    }

    final output = decoded['output'];
    if (output is List) {
      for (final item in output) {
        if (item is Map && item['content'] is List) {
          final content = item['content'] as List;
          for (final part in content) {
            if (part is Map && part['text'] is String) {
              final text = (part['text'] as String).trim();
              if (text.isNotEmpty) return text;
            }
          }
        }
      }
    }

    return null;
  }
}
