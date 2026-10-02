import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:universal_screencast/universal_screencast.dart';

/// Frames from a running Flutter app, grabbed through the harness's own
/// [VmClient] — the consumer-owned adapter of the capture split
/// (ADR 0038): the harness drives, `universal_screencast` defines the
/// frame contract, and THIS package (the composition) owns the glue
/// between them. No pipeline dependency leaks into the harness; no
/// harness dependency reaches the family.
///
/// Pacing and single-flight stay at the source ([PollingFrameSource]
/// discipline): a slow screenshot skips ticks. Frames are PNG
/// (`view_screenshots` with `compress: false`) and read-only —
/// `frames != semantics`; for the widget tree use a [ToolkitDriver].
final class FlutterAppFrames implements FrameSource {
  /// Creates a source polling [client]'s toolkit screenshot extension
  /// every [interval].
  FlutterAppFrames({
    required VmClient client,
    Duration interval = const Duration(milliseconds: 250),
  }) : _delegate = PollingFrameSource(
         () => _grab(client),
         interval: interval,
         contentType: 'image/png',
       );

  static const String _id = 'toolkit-flutter';

  final PollingFrameSource _delegate;

  /// Decodes the main view's PNG out of the `view_screenshots` envelope.
  static Future<Uint8List> _grab(VmClient client) async {
    final raw = await client.callExtension(
      ToolkitExtensions.viewScreenshots,
      args: {'compress': false},
    );
    final data = (raw['data'] ?? raw) as Map<Object?, Object?>;
    final images = (data['images'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toList();
    if (images.isEmpty) {
      throw StateError('view_screenshots returned no images');
    }
    // Multi-view apps list every view; the first is the main one.
    return base64Decode(images.first);
  }

  @override
  String get id => _id;

  @override
  SourceCapabilities get capabilities => _delegate.capabilities;

  @override
  Stream<Frame> start() => _delegate.start().map(
    (frame) => Frame(
      sourceId: _id,
      sequence: frame.sequence,
      revision: frame.revision,
      bytes: frame.bytes,
      contentType: frame.contentType,
      capturedAt: frame.capturedAt,
    ),
  );

  @override
  Future<void> stop() => _delegate.stop();
}
