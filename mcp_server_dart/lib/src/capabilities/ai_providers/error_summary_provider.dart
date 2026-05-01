// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io' as io;

/// Lifecycle of a summarization attempt (wire values: ok, skipped, failed).
enum ErrorSummaryStatus {
  ok,
  skipped,
  failed,
}

/// Result of a summarization attempt; providers must not throw for expected paths.
final class ErrorSummaryOutcome {
  const ErrorSummaryOutcome({
    required this.status,
    this.text,
    this.reasonCode,
    this.safeDetail,
  });

  final ErrorSummaryStatus status;
  final String? text;
  final String? reasonCode;
  final String? safeDetail;

  static ErrorSummaryOutcome okText(final String text) {
    final t = text.trim();
    if (t.isEmpty) {
      return ErrorSummaryOutcome.failed(
        reasonCode: 'invalid_response',
        safeDetail: 'Summary text was empty.',
      );
    }
    return ErrorSummaryOutcome(
      status: ErrorSummaryStatus.ok,
      text: t,
      reasonCode: null,
      safeDetail: null,
    );
  }

  static ErrorSummaryOutcome skipped({
    required final String reasonCode,
    final String? safeDetail,
  }) => ErrorSummaryOutcome(
    status: ErrorSummaryStatus.skipped,
    text: null,
    reasonCode: reasonCode,
    safeDetail: safeDetail,
  );

  static ErrorSummaryOutcome failed({
    required final String reasonCode,
    final String? safeDetail,
  }) => ErrorSummaryOutcome(
    status: ErrorSummaryStatus.failed,
    text: null,
    reasonCode: reasonCode,
    safeDetail: safeDetail,
  );
}

/// Gating + defensive catch for `explain_errors` summarization (unit-tested).
Future<ErrorSummaryOutcome> resolveExplainErrorsSummary({
  required final bool includeSummary,
  required final bool allowExternalSummary,
  required final ErrorSummaryProvider provider,
  required final Future<ErrorSummaryOutcome> Function() summarize,
}) async {
  if (!includeSummary) {
    return ErrorSummaryOutcome.skipped(reasonCode: 'not_requested');
  }
  if (provider.requiresExternalConsent && !allowExternalSummary) {
    return ErrorSummaryOutcome.skipped(
      reasonCode: 'external_consent_required',
      safeDetail:
          'Set allowExternalSummary to true to send diagnostics to the '
          'summary provider (${provider.id}).',
    );
  }
  try {
    return await summarize();
  } on Object catch (e) {
    return ErrorSummaryOutcome.failed(
      reasonCode: 'unexpected',
      safeDetail: 'Summarization failed: $e',
    );
  }
}

abstract interface class ErrorSummaryProvider {
  String get id;

  /// When true, [summarize] may send diagnostics off-device; callers must gate
  /// on user consent before invoking.
  bool get requiresExternalConsent;

  Future<ErrorSummaryOutcome> summarize({
    required final List<Map<String, Object?>> errors,
    required final List<Map<String, Object?>> causes,
  });
}

final class NoopErrorSummaryProvider implements ErrorSummaryProvider {
  const NoopErrorSummaryProvider();

  @override
  String get id => 'none';

  @override
  bool get requiresExternalConsent => false;

  @override
  Future<ErrorSummaryOutcome> summarize({
    required final List<Map<String, Object?>> errors,
    required final List<Map<String, Object?>> causes,
  }) async => ErrorSummaryOutcome.skipped(
    reasonCode: 'provider_none',
    safeDetail: 'No AI summarization (summaryProvider is none).',
  );
}

final class OpenAiErrorSummaryProvider implements ErrorSummaryProvider {
  OpenAiErrorSummaryProvider({
    final String? apiKey,
    final String model = 'gpt-5.4-mini',
    final Uri? endpoint,
    final Duration timeout = const Duration(seconds: 20),
  }) : _summarizer = _OpenAiResponsesSummarizer(
         apiKey: apiKey ?? io.Platform.environment['OPENAI_API_KEY'] ?? '',
         model: model,
         endpoint: endpoint ?? Uri.parse('https://api.openai.com/v1/responses'),
         timeout: timeout,
       );

  final _OpenAiResponsesSummarizer _summarizer;

  @override
  String get id => 'openai';

  @override
  bool get requiresExternalConsent => true;

  @override
  Future<ErrorSummaryOutcome> summarize({
    required final List<Map<String, Object?>> errors,
    required final List<Map<String, Object?>> causes,
  }) =>
      _summarizer.summarize(errors: errors, causes: causes);
}

final class _OpenAiResponsesSummarizer {
  _OpenAiResponsesSummarizer({
    required this.apiKey,
    required this.model,
    required this.endpoint,
    required this.timeout,
  });

  final String apiKey;
  final String model;
  final Uri endpoint;
  final Duration timeout;

  Future<ErrorSummaryOutcome> summarize({
    required final List<Map<String, Object?>> errors,
    required final List<Map<String, Object?>> causes,
  }) async {
    if (apiKey.isEmpty) {
      return ErrorSummaryOutcome.failed(
        reasonCode: 'no_api_key',
        safeDetail: 'OPENAI_API_KEY is not set.',
      );
    }

    io.HttpClient? client;
    try {
      client = io.HttpClient();
      client.connectionTimeout = timeout;

      final request = await client.postUrl(endpoint);
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.set('Content-Type', 'application/json');

      final payload = {
        'model': model,
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

      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ErrorSummaryOutcome.failed(
          reasonCode: 'http_error',
          safeDetail: 'OpenAI HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return ErrorSummaryOutcome.failed(
          reasonCode: 'invalid_response',
          safeDetail: 'OpenAI response was not a JSON object.',
        );
      }

      final outputText = decoded['output_text'];
      if (outputText is String && outputText.trim().isNotEmpty) {
        return ErrorSummaryOutcome.okText(outputText);
      }

      final output = decoded['output'];
      if (output is List) {
        for (final item in output) {
          if (item is Map && item['content'] is List) {
            final content = item['content'] as List;
            for (final part in content) {
              if (part is Map && part['text'] is String) {
                final text = (part['text'] as String).trim();
                if (text.isNotEmpty) {
                  return ErrorSummaryOutcome.okText(text);
                }
              }
            }
          }
        }
      }

      return ErrorSummaryOutcome.failed(
        reasonCode: 'invalid_response',
        safeDetail: 'OpenAI response had no summary text.',
      );
    } on io.SocketException catch (e) {
      return ErrorSummaryOutcome.failed(
        reasonCode: 'network_error',
        safeDetail: e.message,
      );
    } on io.HttpException catch (e) {
      return ErrorSummaryOutcome.failed(
        reasonCode: 'http_error',
        safeDetail: e.message,
      );
    } on FormatException catch (e) {
      return ErrorSummaryOutcome.failed(
        reasonCode: 'invalid_response',
        safeDetail: e.message,
      );
    } on Object catch (e) {
      return ErrorSummaryOutcome.failed(
        reasonCode: 'unexpected',
        safeDetail: '$e',
      );
    } finally {
      client?.close(force: true);
    }
  }
}
