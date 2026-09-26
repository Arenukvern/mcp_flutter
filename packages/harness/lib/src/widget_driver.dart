import 'toolkit_extensions.dart';
import 'vm_client.dart';

/// Call signature of one VM service extension invocation. The seam tests
/// use to answer with canned envelopes instead of a live VM.
typedef ExtensionCall = Future<Map<String, dynamic>> Function(
  String name, {
  Map<String, Object?> args,
});

/// High-level widget driving over the MCP toolkit's VM service extensions.
///
/// Snapshots, taps, and text entry become typed calls on the connected
/// app — the same surface the MCP server exposes over MCP, as plain Dart.
final class WidgetDriver {
  /// Drives the app behind [client].
  WidgetDriver(final VmClient client) : _call = client.callExtension;

  /// Drives through a custom [ExtensionCall] (tests, alternate transports).
  WidgetDriver.custom(final ExtensionCall call) : _call = call;

  final ExtensionCall _call;

  /// Returns `(label, ref)` pairs for the visible widget tree.
  Future<List<(String, String)>> snapshot() async {
    final nodes = await _snapshotNodes();
    return [
      for (final node in nodes)
        if (node is Map && node['label'] is String && node['ref'] is String)
          (node['label']! as String, node['ref']! as String),
    ];
  }

  /// Finds the first widget whose label contains [needle]
  /// (case-insensitive) and returns its ref, retrying until [timeout].
  Future<String?> findRef(
    final String needle, {
    final Duration timeout = const Duration(seconds: 12),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (final (label, ref) in await snapshot()) {
        if (label.toLowerCase().contains(needle.toLowerCase())) return ref;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  Future<void> tap(final String ref) =>
      _call(ToolkitExtensions.tap, args: {'ref': ref});

  /// Taps until [until] fires; returns the tapped ref or null.
  Future<String?> tapUntil(
    final String ref, {
    required final Future<bool> Function() until,
    final int attempts = 5,
  }) async {
    for (var i = 0; i < attempts; i++) {
      await tap(ref);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (await until()) return ref;
    }
    return null;
  }

  Future<void> enterText(final String ref, final String text) =>
      _call(ToolkitExtensions.enterText, args: {'ref': ref, 'text': text});

  /// Returns the first snapshot node `value` matching [predicate].
  ///
  /// Selectable-text nodes carry their content in `value` (not `label`),
  /// which is the deterministic way to read app-rendered data: icon-only
  /// copy buttons and host clipboards make clipboard routes unreliable.
  Future<String?> findValue(
    final bool Function(String value) predicate,
  ) async {
    for (final node in await _snapshotNodes()) {
      if (node is Map) {
        final value = node['value'];
        if (value is String && predicate(value)) return value;
      }
    }
    return null;
  }

  Future<List<Object?>> _snapshotNodes() async {
    final raw = await _call(ToolkitExtensions.snapshot);
    final data = raw['data'] ?? raw;
    return switch (data) {
      final Map<Object?, Object?> data when data['nodes'] is List =>
        data['nodes']! as List<Object?>,
      _ => const <Object?>[],
    };
  }
}
