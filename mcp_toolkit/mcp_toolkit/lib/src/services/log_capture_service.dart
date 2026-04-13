import 'package:flutter/widgets.dart';

/// A service that captures `debugPrint` / `print()` output for retrieval by
/// MCP tools.
///
/// Call [install] once during app bootstrap to start capturing.
mixin LogCaptureService {
  static final List<Map<String, Object?>> _logs = <Map<String, Object?>>[];
  static const int _maxLogs = 200;
  static bool _installed = false;

  /// Install the log capture hook.
  ///
  /// Overrides [debugPrint] so that every print statement is also recorded
  /// in an internal ring buffer. The original [debugPrint] is still called
  /// so normal console output is preserved.
  ///
  /// Safe to call multiple times; subsequent calls are no-ops.
  ///
  /// No-op in test environments (where the test framework asserts that
  /// foundation debug variables remain unchanged).
  static void install() {
    if (_installed) return;
    if (_isInFlutterTest()) return;
    _installed = true;

    final original = debugPrint;
    debugPrint = (final message, {final wrapWidth}) {
      _addLog('print', message ?? '');
      original(message, wrapWidth: wrapWidth);
    };
  }

  static bool _isInFlutterTest() {
    // Detect TestWidgetsFlutterBinding so the override doesn't trip the
    // binding's foundation-vars-unchanged assertion in unit tests.
    try {
      final binding = WidgetsBinding.instance;
      return binding.runtimeType.toString().contains('Test');
    } on Object {
      return false;
    }
  }

  /// Retrieve the most recent [count] log entries (newest first).
  static List<Map<String, Object?>> getRecentLogs({final int count = 50}) {
    final end = _logs.length;
    final start = (end - count).clamp(0, end);
    return _logs.sublist(start, end).reversed.toList(growable: false);
  }

  /// Clear all captured logs.
  static void clear() => _logs.clear();

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  static void _addLog(final String type, final String message) {
    if (_logs.length >= _maxLogs) {
      _logs.removeAt(0);
    }
    _logs.add(<String, Object?>{
      'type': type,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
