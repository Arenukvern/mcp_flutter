import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:test/test.dart';

void main() {
  group('detectPlatformViews', () {
    test('returns none for empty tree', () {
      final hints = detectPlatformViews(null);
      expect(hints.platformViewsDetected, isFalse);
      expect(hints.matches, isEmpty);
    });

    test('detects strong AppKitView signal', () {
      final tree = <String, Object?>{
        'widgetType': 'MaterialApp',
        'children': <Object?>[
          <String, Object?>{
            'widgetType': 'AppKitView',
            'renderObjectType': 'RenderAppKitView',
            'children': const <Object?>[],
          },
        ],
      };

      final hints = detectPlatformViews(tree);
      expect(hints.platformViewsDetected, isTrue);
      expect(hints.recommendedMode, kCaptureHintRecommendedDesktopWindow);
      expect(hints.matches.single.widgetType, 'AppKitView');
      expect(hints.matches.single.renderObjectType, 'RenderAppKitView');
    });

    test('detects strong UiKitView signal', () {
      final tree = <String, Object?>{
        'widgetType': 'MaterialApp',
        'children': <Object?>[
          <String, Object?>{
            'widgetType': 'UiKitView',
            'depth': 1,
            'renderObjectType': 'RenderUiKitView',
            'globalBounds': <String, Object?>{
              'left': 0.0,
              'top': 0.0,
              'width': 100.0,
              'height': 50.0,
            },
            'children': const <Object?>[],
          },
        ],
      };

      final hints = detectPlatformViews(tree);
      expect(hints.platformViewsDetected, isTrue);
      expect(hints.recommendedMode, kCaptureHintRecommendedDesktopWindow);
      expect(hints.matches, hasLength(1));
      expect(hints.matches.first.confidence, 'high');
      expect(hints.matches.first.widgetType, 'UiKitView');
    });

    test('Texture is weak signal only', () {
      final tree = <String, Object?>{
        'widgetType': 'Column',
        'children': <Object?>[
          <String, Object?>{
            'widgetType': 'Texture',
            'children': const <Object?>[],
          },
        ],
      };

      final hints = detectPlatformViews(tree);
      expect(hints.platformViewsDetected, isFalse);
      expect(hints.weakSignalsDetected, isTrue);
      expect(hints.recommendedMode, kCaptureHintRecommendedDesktopWindow);
      expect(hints.warning, kWeakTextureWarning);
      expect(hints.matches.single.confidence, 'low');
    });

    test('plain widgets produce no hints', () {
      final tree = <String, Object?>{
        'widgetType': 'Scaffold',
        'children': <Object?>[
          <String, Object?>{
            'widgetType': 'Text',
            'children': const <Object?>[],
          },
        ],
      };

      expect(detectPlatformViews(tree).platformViewsDetected, isFalse);
    });

    test('truncated node still scanned', () {
      final tree = <String, Object?>{
        'widgetType': 'AndroidView',
        'truncated': true,
        'children': const <Object?>[],
      };

      final hints = detectPlatformViews(tree);
      expect(hints.matches.single.widgetType, 'AndroidView');
    });
  });

  group('platformViewHintsFromCaptureHintsJson', () {
    test('trusts app-embedded captureHints when matches present', () {
      final hints = platformViewHintsFromCaptureHintsJson(<String, Object?>{
        'platformViewsDetected': true,
        'matches': <Object?>[
          <String, Object?>{
            'widgetType': 'AppKitView',
            'depth': 12,
            'confidence': 'high',
            'renderObjectType': 'RenderAppKitView',
          },
        ],
      });
      expect(hints.platformViewsDetected, isTrue);
      expect(hints.matches.single.widgetType, 'AppKitView');
    });
  });

  group('mergeCaptureHintMetadata', () {
    test('adds captureHints and warnings when detected', () {
      final hints = detectPlatformViews(<String, Object?>{
        'widgetType': 'HtmlElementView',
        'children': const <Object?>[],
      });
      final merged = mergeCaptureHintMetadata(
        data: <String, Object?>{'images': <String>[]},
        hints: hints,
        extraWarnings: const <String>['extra'],
      );

      expect(merged['captureHints'], isA<Map<String, Object?>>());
      expect(merged['warnings'], contains('extra'));
      expect(merged['warnings'], contains(kPlatformViewWarning));
      expect(merged['suggestedAction'], isNotNull);
    });

    test('adds captureHints for weak Texture signals', () {
      final hints = detectPlatformViews(<String, Object?>{
        'widgetType': 'Column',
        'children': <Object?>[
          <String, Object?>{'widgetType': 'Texture', 'children': const []},
        ],
      });
      final merged = mergeCaptureHintMetadata(
        data: <String, Object?>{'images': <String>[]},
        hints: hints,
      );

      final captureHints = merged['captureHints']! as Map<String, Object?>;
      expect(captureHints['weakSignalsDetected'], isTrue);
      expect(captureHints['platformViewsDetected'], isFalse);
      expect(merged['warnings'], contains(kWeakTextureWarning));
      expect(merged['suggestedAction'], isNotNull);
    });
  });
}
