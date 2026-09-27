import 'dart:async';

/// Broadcast tap on a process's stdout/stderr lines.
///
/// Every line is retained (bounded) and pushed to listeners; steps assert
/// with [waitFor] instead of sleep-and-grep.
final class LogTap {
  LogTap({this.maxLines = 4000});

  final int maxLines;
  final List<String> _lines = <String>[];
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  // Waiters in flight from [waitFor]; [close] settles them so a dead child
  // fails its waiters fast instead of leaving them until the timeout.
  final List<(Pattern, Completer<String>)> _waits =
      <(Pattern, Completer<String>)>[];

  int get lineCount => _lines.length;

  List<String> get lines => List.unmodifiable(_lines);

  /// Live line feed (lines emitted after subscribing; the buffer is not
  /// replayed — use [waitFor]/[lines] for that).
  Stream<String> get stream => _controller.stream;

  void add(final String line) {
    _lines.add(line);
    if (_lines.length > maxLines) {
      _lines.removeRange(0, _lines.length - maxLines);
    }
    if (!_controller.isClosed) _controller.add(line);
  }

  /// First line matching [pattern], or null.
  String? firstMatch(final Pattern pattern) {
    for (final line in _lines) {
      if (line.contains(pattern)) return line;
    }
    return null;
  }

  int count(final Pattern pattern) =>
      _lines.where((final line) => line.contains(pattern)).length;

  /// The last [n] retained lines (fewer if the buffer is younger).
  List<String> tail(final int n) =>
      _lines.length <= n ? List.of(_lines) : _lines.sublist(_lines.length - n);

  /// Waits up to [timeout] for a line matching [pattern]; returns it.
  /// Throws [TimeoutException] on expiry (steps convert that to failure),
  /// or [StateError] if the tap closes first (the child process died —
  /// nothing more can match).
  Future<String> waitFor(
    final Pattern pattern, {
    final Duration timeout = const Duration(seconds: 30),
    final Duration poll = const Duration(milliseconds: 100),
  }) async {
    final existing = firstMatch(pattern);
    if (existing != null) return existing;
    final done = Completer<String>();
    final wait = (pattern, done);
    _waits.add(wait);
    void settled() => _waits.remove(wait);
    final sub = _controller.stream.listen((final line) {
      if (!done.isCompleted && line.contains(pattern)) {
        settled();
        done.complete(line);
      }
    });
    final timer = Timer(timeout, () {
      if (!done.isCompleted) {
        settled();
        done.completeError(
          TimeoutException('no line matching $pattern after $timeout'),
        );
      }
    });
    try {
      return await done.future;
    } finally {
      settled();
      timer.cancel();
      await sub.cancel();
    }
  }

  /// Closes the stream; pending [waitFor]s fail with a [StateError].
  Future<void> close() {
    for (final (pattern, done) in _waits) {
      if (!done.isCompleted) {
        done.completeError(StateError('tap closed while waiting for $pattern'));
      }
    }
    _waits.clear();
    return _controller.close();
  }
}
