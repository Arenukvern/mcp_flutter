import 'dart:async';

/// Hard toolkit attach verbs did not register before the deadline.
final class ToolkitNotReady extends TimeoutException {
  ToolkitNotReady({
    required Duration duration,
    required List<String> missingHardExtensions,
    this.diagnosticUri,
  })  : missingHardExtensions = List.unmodifiable(missingHardExtensions),
        super(
          _message(duration, missingHardExtensions, diagnosticUri),
          duration,
        );

  final List<String> missingHardExtensions;
  final Uri? diagnosticUri;
}

String _message(
  Duration duration,
  List<String> missing,
  Uri? diagnosticUri,
) {
  final target = diagnosticUri == null ? '' : ' on $diagnosticUri';
  return 'MCP toolkit extensions not registered within $duration$target '
      '(missing: ${missing.join(', ')})';
}
