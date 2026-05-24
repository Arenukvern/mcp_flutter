import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/platform_view_hints.dart';
import 'package:test/test.dart';

void main() {
  test('re-exports core detector for server consumers', () {
    final hints = detectPlatformViews(<String, Object?>{
      'widgetType': 'PlatformViewLink',
      'children': const <Object?>[],
    });
    expect(hints.platformViewsDetected, isTrue);
    expect(
      mergeCaptureHintMetadata(data: <String, Object?>{}, hints: hints)['captureHints'],
      isNotNull,
    );
  });
}
