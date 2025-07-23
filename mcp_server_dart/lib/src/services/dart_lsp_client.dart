// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// {@template dart_lsp_client}
/// Tiny LSP client for accessing Dart analysis server documentation features.
///
/// Specifically handles:
/// - textDocument/hover for symbol documentation
/// - textDocument/definition for navigation
/// - initialize/shutdown lifecycle
/// {@endtemplate}
@immutable
final class DartLspClient {
  /// {@macro dart_lsp_client}
  DartLspClient({
    required this.logger,
    this.timeout = const Duration(seconds: 10),
    this.dartSdkPath,
  });

  /// Logger for LSP operations
  final Logger logger;

  /// Timeout for LSP operations
  final Duration timeout;

  /// Optional path to Dart SDK (will auto-detect if not provided)
  final String? dartSdkPath;

  /// Current request ID counter
  static var _requestId = 0;

  /// Active LSP server process
  Process? _serverProcess;

  /// Server stdin for sending requests
  IOSink? _serverStdin;

  /// Server stdout subscription for receiving responses
  StreamSubscription? _stdoutSubscription;

  /// Response completers keyed by request ID
  final Map<int, Completer<Map<String, dynamic>>> _responseCompleters = {};

  /// Whether the server is initialized
  var _isInitialized = false;

  /// Buffer for incoming message data
  var _messageBuffer = '';

  /// Get the next request ID
  static int get _nextRequestId => ++_requestId;

  /// Start the Dart analysis server in LSP mode
  Future<bool> start() async {
    try {
      final dartExecutable = await _findDartExecutable();
      if (dartExecutable == null) {
        logger.severe('Could not find Dart executable');
        return false;
      }

      logger.info('Starting Dart LSP server: $dartExecutable');

      _serverProcess = await Process.start(dartExecutable, ['language-server']);

      // Check if process started successfully
      if (_serverProcess == null) {
        logger.severe('Failed to start Dart LSP server process');
        return false;
      }

      logger.info(
        'Dart LSP server process started (PID: ${_serverProcess!.pid})',
      );

      _serverStdin = _serverProcess!.stdin;

      // Listen for stderr to catch any startup errors
      _serverProcess!.stderr.listen(
        (final data) => logger.warning('LSP stderr: ${utf8.decode(data)}'),
        onError: (final error) => logger.severe('LSP stderr error: $error'),
      );

      // Listen for raw bytes from server
      _stdoutSubscription = _serverProcess!.stdout.listen(
        _handleServerData,
        onError: (final error) => logger.severe('LSP server error: $error'),
        onDone: () => logger.info('LSP server connection closed'),
      );

      // Initialize the server
      final initialized = await _initialize();
      if (!initialized) {
        await shutdown();
        return false;
      }

      logger.info('Dart LSP client started successfully');
      return true;
    } catch (e, stackTrace) {
      logger.severe('Failed to start Dart LSP server: $e', e, stackTrace);
      return false;
    }
  }

  /// Shutdown the LSP server
  Future<void> shutdown() async {
    try {
      if (_isInitialized) {
        await _sendRequest('shutdown', {});
        await _sendNotification('exit', {});
        _isInitialized = false;
      }

      await _serverStdin?.close();
      await _stdoutSubscription?.cancel();
      _serverProcess?.kill();
      _serverProcess = null;
      _serverStdin = null;
      _stdoutSubscription = null;

      // Complete any pending requests with errors
      for (final completer in _responseCompleters.values) {
        if (!completer.isCompleted) {
          completer.completeError('LSP server shutdown');
        }
      }
      _responseCompleters.clear();

      logger.info('Dart LSP client shutdown');
    } catch (e) {
      logger.warning('Error during LSP shutdown: $e');
    }
  }

  /// Get hover information for a symbol at the given position
  ///
  /// [filePath] - Absolute path to the Dart file
  /// [line] - Line number (0-based)
  /// [character] - Character position (0-based)
  ///
  /// Returns the hover documentation or null if not found
  Future<String?> getHover(
    final String filePath,
    final int line,
    final int character,
  ) async {
    if (!_isInitialized) {
      logger.warning('LSP client not initialized');
      return null;
    }

    try {
      // Ensure file is opened
      await _openDocument(filePath);

      final response = await _sendRequest('textDocument/hover', {
        'textDocument': {'uri': _pathToUri(filePath)},
        'position': {'line': line, 'character': character},
      });

      final result = response['result'] as Map<String, dynamic>?;
      if (result == null) return null;

      final contents = result['contents'];
      if (contents is Map<String, dynamic>) {
        return contents['value'] as String?;
      } else if (contents is String) {
        return contents;
      } else if (contents is List) {
        return contents
            .map((final item) {
              if (item is Map<String, dynamic>) {
                return item['value'] as String? ?? item.toString();
              }
              return item.toString();
            })
            .where((final s) => s.isNotEmpty)
            .join('\n\n');
      }

      return null;
    } catch (e) {
      logger.warning('Error getting hover info: $e');
      return null;
    }
  }

  /// Get definition location for a symbol at the given position
  ///
  /// [filePath] - Absolute path to the Dart file
  /// [line] - Line number (0-based)
  /// [character] - Character position (0-based)
  ///
  /// Returns list of definition locations
  Future<List<LspLocation>> getDefinition(
    final String filePath,
    final int line,
    final int character,
  ) async {
    if (!_isInitialized) {
      logger.warning('LSP client not initialized');
      return [];
    }

    try {
      await _openDocument(filePath);

      final response = await _sendRequest('textDocument/definition', {
        'textDocument': {'uri': _pathToUri(filePath)},
        'position': {'line': line, 'character': character},
      });

      final result = response['result'];
      if (result == null) return [];

      final locations = <LspLocation>[];
      if (result is List) {
        for (final item in result) {
          if (item is Map<String, dynamic>) {
            final location = LspLocation.fromJson(item);
            if (location != null) locations.add(location);
          }
        }
      } else if (result is Map<String, dynamic>) {
        final location = LspLocation.fromJson(result);
        if (location != null) locations.add(location);
      }

      return locations;
    } catch (e) {
      logger.warning('Error getting definition: $e');
      return [];
    }
  }

  /// Find documentation for a symbol by searching in the given file
  ///
  /// [filePath] - Path to the Dart file to search
  /// [symbolName] - Name of the symbol to find
  ///
  /// Returns documentation if found
  Future<String?> findSymbolDocumentation(
    final String filePath,
    final String symbolName,
  ) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;

      final content = await file.readAsString();
      final lines = content.split('\n');

      // Find the symbol definition
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_isSymbolDefinition(line, symbolName)) {
          // Try to get hover info at this position
          final character = line.indexOf(symbolName);
          if (character >= 0) {
            final hover = await getHover(filePath, i, character);
            if (hover != null && hover.isNotEmpty) {
              return hover;
            }
          }
        }
      }

      return null;
    } catch (e) {
      logger.warning('Error finding symbol documentation: $e');
      return null;
    }
  }

  /// Check if the LSP server is running and initialized
  bool get isInitialized => _isInitialized && _serverProcess != null;

  // Private methods

  /// Find the Dart executable
  Future<String?> _findDartExecutable() async {
    // Try provided SDK path first
    if (dartSdkPath != null) {
      final dartExe = p.join(dartSdkPath!, 'bin', 'dart');
      if (File(dartExe).existsSync()) return dartExe;
    }

    // Try common locations
    final commonPaths = [
      '/usr/local/bin/dart',
      '/usr/bin/dart',
      p.join(
        Platform.environment['HOME'] ?? '',
        'fvm',
        'default',
        'bin',
        'dart',
      ),
    ];

    for (final path in commonPaths) {
      if (File(path).existsSync()) return path;
    }

    // Try PATH
    try {
      final result = await Process.run('which', ['dart']);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}

    return null;
  }

  /// Initialize the LSP server
  Future<bool> _initialize() async {
    try {
      logger.info('Sending initialize request...');
      final response = await _sendRequest('initialize', {
        'processId': pid,
        'clientInfo': {'name': 'Flutter Inspector MCP', 'version': '1.0.0'},
        'capabilities': {
          'textDocument': {
            'hover': {
              'contentFormat': ['markdown', 'plaintext'],
            },
            'definition': {'linkSupport': false},
          },
        },
        'workspaceFolders': null,
        'rootUri': null,
      });

      logger.info('Initialize response received: ${response.keys}');

      if (response['result'] != null) {
        logger.info('Sending initialized notification...');
        await _sendNotification('initialized', {});
        _isInitialized = true;
        logger.info('LSP server initialized successfully');
        return true;
      } else if (response['error'] != null) {
        logger.severe('Initialize error: ${response['error']}');
        return false;
      }

      logger.warning('Initialize response missing result');
      return false;
    } catch (e) {
      logger.severe('Failed to initialize LSP server: $e');
      return false;
    }
  }

  /// Open a document in the LSP server
  Future<void> _openDocument(final String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return;

      final content = await file.readAsString();
      await _sendNotification('textDocument/didOpen', {
        'textDocument': {
          'uri': _pathToUri(filePath),
          'languageId': 'dart',
          'version': 1,
          'text': content,
        },
      });
    } catch (e) {
      logger.warning('Error opening document: $e');
    }
  }

  /// Send an LSP request and wait for response
  Future<Map<String, dynamic>> _sendRequest(
    final String method,
    final Map<String, dynamic> params,
  ) async {
    final id = _nextRequestId;
    final completer = Completer<Map<String, dynamic>>();
    _responseCompleters[id] = completer;

    final request = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    };

    await _sendMessage(request);

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _responseCompleters.remove(id);
        throw TimeoutException('LSP request timeout: $method', timeout);
      },
    );
  }

  /// Send an LSP notification (no response expected)
  Future<void> _sendNotification(
    final String method,
    final Map<String, dynamic> params,
  ) async {
    final notification = {'jsonrpc': '2.0', 'method': method, 'params': params};

    await _sendMessage(notification);
  }

  /// Send a message to the LSP server
  Future<void> _sendMessage(final Map<String, dynamic> message) async {
    if (_serverStdin == null) {
      throw StateError('LSP server not started');
    }

    final content = jsonEncode(message);
    final header = 'Content-Length: ${content.length}\r\n\r\n';

    logger.fine('Sending LSP message: $header$content');

    _serverStdin!.write(header);
    _serverStdin!.write(content);
    await _serverStdin!.flush();
  }

  /// Handle incoming raw data from server
  void _handleServerData(final List<int> data) {
    try {
      _messageBuffer += utf8.decode(data);
      _processMessages();
    } catch (e) {
      logger.warning('Error handling server data: $e');
    }
  }

  /// Process complete messages from buffer
  void _processMessages() {
    while (true) {
      // Look for Content-Length header
      final headerEndIndex = _messageBuffer.indexOf('\r\n\r\n');
      if (headerEndIndex == -1) {
        // No complete header yet
        return;
      }

      final headerSection = _messageBuffer.substring(0, headerEndIndex);
      final contentLengthMatch = RegExp(
        r'Content-Length: (\d+)',
      ).firstMatch(headerSection);

      if (contentLengthMatch == null) {
        logger.warning('No Content-Length header found');
        _messageBuffer = _messageBuffer.substring(headerEndIndex + 4);
        continue;
      }

      final contentLength = int.parse(contentLengthMatch.group(1)!);
      final messageStart = headerEndIndex + 4;
      final messageEnd = messageStart + contentLength;

      if (_messageBuffer.length < messageEnd) {
        // Message not complete yet
        return;
      }

      final messageContent = _messageBuffer.substring(messageStart, messageEnd);
      _messageBuffer = _messageBuffer.substring(messageEnd);

      _handleJsonMessage(messageContent);
    }
  }

  /// Handle a complete JSON message
  void _handleJsonMessage(final String content) {
    try {
      logger.fine('Received LSP message: $content');
      final message = jsonDecode(content) as Map<String, dynamic>;
      final id = message['id'];

      if (id != null && _responseCompleters.containsKey(id)) {
        final completer = _responseCompleters.remove(id)!;
        if (!completer.isCompleted) {
          completer.complete(message);
        }
      } else {
        logger.info(
          'Received notification or unmatched response: ${message['method'] ?? 'unknown'}',
        );
      }
    } catch (e) {
      logger.warning('Error parsing JSON message: $e\nContent: $content');
    }
  }

  /// Convert file path to URI
  String _pathToUri(final String filePath) => 'file://$filePath';

  /// Check if a line contains a symbol definition
  bool _isSymbolDefinition(final String line, final String symbolName) {
    final trimmed = line.trim();

    // Check for class definitions
    if (trimmed.contains('class $symbolName') ||
        trimmed.contains('abstract class $symbolName') ||
        trimmed.contains('sealed class $symbolName')) {
      return true;
    }

    // Check for function definitions
    if (trimmed.contains('$symbolName(') &&
        (trimmed.contains('void ') ||
            trimmed.contains('Future') ||
            trimmed.contains('String ') ||
            trimmed.contains('int ') ||
            trimmed.contains('bool ') ||
            trimmed.contains('double '))) {
      return true;
    }

    // Check for variable definitions
    if (trimmed.contains('final $symbolName') ||
        trimmed.contains('const $symbolName') ||
        trimmed.contains('var $symbolName') ||
        trimmed.contains('late $symbolName')) {
      return true;
    }

    return false;
  }
}

/// {@template lsp_location}
/// Represents a location in an LSP response
/// {@endtemplate}
@immutable
final class LspLocation {
  /// {@macro lsp_location}
  const LspLocation({required this.uri, required this.range});

  /// File URI
  final String uri;

  /// Range within the file
  final LspRange range;

  /// Create from JSON
  static LspLocation? fromJson(final Map<String, dynamic> json) {
    try {
      final uri = json['uri'] as String?;
      final rangeJson = json['range'] as Map<String, dynamic>?;

      if (uri == null || rangeJson == null) return null;

      final range = LspRange.fromJson(rangeJson);
      if (range == null) return null;

      return LspLocation(uri: uri, range: range);
    } catch (_) {
      return null;
    }
  }

  /// Get file path from URI
  String get filePath {
    final parsedUri = Uri.parse(uri);
    return parsedUri.toFilePath();
  }
}

/// {@template lsp_range}
/// Represents a range in an LSP response
/// {@endtemplate}
@immutable
final class LspRange {
  /// {@macro lsp_range}
  const LspRange({required this.start, required this.end});

  /// Start position
  final LspPosition start;

  /// End position
  final LspPosition end;

  /// Create from JSON
  static LspRange? fromJson(final Map<String, dynamic> json) {
    try {
      final startJson = json['start'] as Map<String, dynamic>?;
      final endJson = json['end'] as Map<String, dynamic>?;

      if (startJson == null || endJson == null) return null;

      final start = LspPosition.fromJson(startJson);
      final end = LspPosition.fromJson(endJson);

      if (start == null || end == null) return null;

      return LspRange(start: start, end: end);
    } catch (_) {
      return null;
    }
  }
}

/// {@template lsp_position}
/// Represents a position in an LSP response
/// {@endtemplate}
@immutable
final class LspPosition {
  /// {@macro lsp_position}
  const LspPosition({required this.line, required this.character});

  /// Line number (0-based)
  final int line;

  /// Character position (0-based)
  final int character;

  /// Create from JSON
  static LspPosition? fromJson(final Map<String, dynamic> json) {
    try {
      final line = json['line'] as int?;
      final character = json['character'] as int?;

      if (line == null || character == null) return null;

      return LspPosition(line: line, character: character);
    } catch (_) {
      return null;
    }
  }
}
