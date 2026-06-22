import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/desktop_capture_recovery.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/desktop_window_screenshot.dart';
import 'package:test/test.dart';

void main() {
  group('resolveEffectiveScreenshotMode', () {
    test('auto upgrades when platform views on macOS host', () {
      final hints = detectPlatformViews(<String, Object?>{
        'widgetType': 'UiKitView',
        'children': const <Object?>[],
      });
      expect(
        resolveEffectiveScreenshotMode(
          requested: ScreenshotMode.auto,
          hints: hints,
          hostDesktopCaptureViable: true,
        ),
        ScreenshotMode.desktopWindow,
      );
    });

    test('auto unchanged without platform views', () {
      expect(
        resolveEffectiveScreenshotMode(
          requested: ScreenshotMode.auto,
          hints: PlatformViewHints.none,
          hostDesktopCaptureViable: true,
        ),
        ScreenshotMode.auto,
      );
    });
  });

  group('captureDesktopWithRecovery', () {
    test('succeeds on first capture without retry', () async {
      var focusCount = 0;
      var captureCount = 0;
      final service = _CountingDesktopService(
        onFocus: () => focusCount++,
        onCapture: () => captureCount++,
        captures: <DesktopWindowScreenshotCapture?>[
          const DesktopWindowScreenshotCapture(
            images: <String>['a'],
            captureMode: 'desktop_window',
          ),
        ],
      );

      final result = await captureDesktopWithRecovery(
        service: service,
        projectDir: '/tmp',
        device: 'macos',
        compress: true,
        targetPid: 1,
        cacheDir: null,
        hints: PlatformViewHints.none,
        explicitDesktopMode: true,
      );

      expect(result.capture, isNotNull);
      expect(result.retried, isFalse);
      expect(focusCount, 0);
      expect(captureCount, 1);
    });

    test(
      'retries focus+capture when first fails with platform views',
      () async {
        var focusCount = 0;
        var captureCount = 0;
        final service = _CountingDesktopService(
          onFocus: () => focusCount++,
          onCapture: () => captureCount++,
          captures: <DesktopWindowScreenshotCapture?>[
            null,
            const DesktopWindowScreenshotCapture(
              images: <String>['b'],
              captureMode: 'desktop_window',
            ),
          ],
        );

        final hints = detectPlatformViews(<String, Object?>{
          'widgetType': 'AndroidView',
          'children': const <Object?>[],
        });

        final result = await captureDesktopWithRecovery(
          service: service,
          projectDir: '/tmp',
          device: 'macos',
          compress: true,
          targetPid: null,
          cacheDir: null,
          hints: hints,
          explicitDesktopMode: true,
        );

        expect(result.capture?.images, equals(const <String>['b']));
        expect(result.retried, isTrue);
        expect(focusCount, 1);
        expect(captureCount, 2);
        expect(result.recoveryMetadata()['desktopCaptureRetried'], isTrue);
      },
    );

    test('does not retry without platform views or explicit desktop', () async {
      var captureCount = 0;
      final service = _CountingDesktopService(
        onCapture: () => captureCount++,
        captures: <DesktopWindowScreenshotCapture?>[null],
      );

      final result = await captureDesktopWithRecovery(
        service: service,
        projectDir: '/tmp',
        device: 'macos',
        compress: true,
        targetPid: null,
        cacheDir: null,
        hints: PlatformViewHints.none,
        explicitDesktopMode: false,
      );

      expect(result.capture, isNull);
      expect(result.retried, isFalse);
      expect(captureCount, 1);
    });

    test(
      'preserves first focus and second failure details after retry',
      () async {
        final service = _CountingDesktopService(
          captures: <DesktopWindowScreenshotCapture?>[null, null],
        );

        final hints = detectPlatformViews(<String, Object?>{
          'widgetType': 'UiKitView',
          'children': const <Object?>[],
        });

        final result = await captureDesktopWithRecovery(
          service: service,
          projectDir: '/tmp',
          device: 'macos',
          compress: true,
          targetPid: 42,
          cacheDir: null,
          hints: hints,
          explicitDesktopMode: true,
        );

        expect(result.capture, isNull);
        expect(result.retried, isTrue);
        expect(
          result.errorDetails['firstAttempt'],
          isA<Map<String, Object?>>(),
        );
        expect(
          result.errorDetails['focus'],
          equals(<String, Object?>{'ok': true}),
        );
        expect(
          result.errorDetails['secondAttempt'],
          isA<Map<String, Object?>>(),
        );
      },
    );
  });
}

final class _CountingDesktopService implements DesktopWindowScreenshotService {
  _CountingDesktopService({
    required this.captures,
    this.onFocus,
    this.onCapture,
  });

  final List<DesktopWindowScreenshotCapture?> captures;
  final void Function()? onFocus;
  final void Function()? onCapture;
  var _index = 0;

  @override
  Future<Map<String, Object?>> focus({
    required final String device,
    final int? targetPid,
    final String? cacheDir,
  }) async {
    onFocus?.call();
    return <String, Object?>{'ok': true};
  }

  @override
  Future<DesktopWindowScreenshotCapture?> capture({
    required final String projectDir,
    required final String device,
    required final bool compress,
    final int? targetPid,
    final String? cacheDir,
  }) async {
    onCapture?.call();
    if (_index >= captures.length) {
      return null;
    }
    return captures[_index++];
  }
}
