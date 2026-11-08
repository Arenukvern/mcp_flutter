@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:universal_automation_interface/universal_automation_interface.dart';

import 'native_layer_capture_layout.dart';
import 'native_layer_evidence.dart';

Uint8List _encode(img.Image image) => Uint8List.fromList(img.encodePng(image));

(img.Image, NativeCaptureLayout) _fixture320({required String counterGlyph}) {
  final image = img.Image(width: 320, height: 240);
  final layout = NativeCaptureLayout.identityForImage(image);
  for (var y = 0; y < layout.markerStripePhysicalPx; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, 0x22, 0xAA, 0x55, 0xFF);
    }
  }
  final (left, top, _, _) = layout.counterTextPhysicalRoi;
  if (counterGlyph == '0') {
    img.drawString(
      image,
      counterGlyph,
      font: img.arial24,
      x: left,
      y: top,
      color: img.ColorRgba8(0, 0, 0, 255),
    );
  } else if (counterGlyph == '1') {
    final (_, _, w, h) = layout.counterTextPhysicalRoi;
    for (var y = top; y < top + h && y < image.height; y++) {
      for (var x = left; x < left + w && x < image.width; x++) {
        image.setPixelRgba(x, y, 0, 0, 0, 255);
      }
    }
    img.drawString(
      image,
      counterGlyph,
      font: img.arial24,
      x: left,
      y: top,
      color: img.ColorRgba8(255, 255, 255, 255),
    );
  }
  return (image, layout);
}

void main() {
  group('NativeCaptureLayout geometry table', () {
    test('1080x2274 @ marker width 411 → exact physical stripe rect', () {
      final layout = NativeCaptureLayout.fromSemantics(
        imageWidth: 1080,
        imageHeight: 2274,
        marker: const AxBounds(left: 0, top: 0, width: 411, height: 8),
        counter: const AxBounds(left: 24, top: 32, width: 80, height: 56),
      );
      expect(layout, isNotNull);
      expect(layout!.scale, closeTo(1080 / 411, 0.001));
      expect(layout.markerStripePhysicalTop, 0);
      expect(layout.markerStripePhysicalLeft, 0);
      expect(layout.markerStripePhysicalWidth, 1080);
      expect(layout.markerStripePhysicalPx, 21);
    });

    test('stripe ROI follows semantics top/left when marker is inset', () {
      final layout = NativeCaptureLayout.fromSemantics(
        imageWidth: 1080,
        imageHeight: 2274,
        marker: const AxBounds(left: 0, top: 24, width: 411, height: 8),
        counter: const AxBounds(left: 24, top: 56, width: 80, height: 56),
      );
      expect(layout!.markerStripePhysicalTop, 63);
      expect(layout.markerStripePhysicalLeft, 0);
      expect(layout.markerStripePhysicalWidth, 1080);
      expect(layout.markerStripePhysicalPx, 21);
    });

    test('1280x720 @ logical 1:1 → exact 8px full-width stripe', () {
      final layout = NativeCaptureLayout.fromSemantics(
        imageWidth: 1280,
        imageHeight: 720,
        marker: const AxBounds(left: 0, top: 0, width: 1280, height: 8),
        counter: const AxBounds(left: 24, top: 32, width: 200, height: 56),
      );
      expect(layout!.markerStripePhysicalTop, 0);
      expect(layout.markerStripePhysicalLeft, 0);
      expect(layout.markerStripePhysicalWidth, 1280);
      expect(layout.markerStripePhysicalPx, 8);
    });
  });

  group('analyzeCapturePair', () {
    test('passes on green stripe + counter ROI delta when semantics counter +1', () {
      final (img0, layout) = _fixture320(counterGlyph: '0');
      final (img1, _) = _fixture320(counterGlyph: '1');
      final proof = analyzeCapturePair(
        before: _encode(img0),
        after: _encode(img1),
        counterBefore: 0,
        counterAfter: 1,
        layout: layout,
      );
      expect(proof['verdict'], 'pass');
      expect(proof['counterRoiDiffPixels'], greaterThanOrEqualTo(kMinCounterRoiDiffPixels));
      expect(
        (proof['markerStripeBefore'] as Map)['interiorExactGreenRatio'],
        1.0,
      );
    });

    test('interior exact green is 1.0 on unmodified synthetic stripe', () {
      final (image, layout) = _fixture320(counterGlyph: '0');
      final stripe = analyzeMarkerStripe(image, layout: layout);
      expect(stripe['interiorExactGreenRatio'], 1.0);
    });

    test('fails on identical blank PNGs despite fake counter semantics', () {
      final image = img.Image(width: 320, height: 240);
      final layout = NativeCaptureLayout.identityForImage(image);
      final blank = _encode(image);
      final proof = analyzeCapturePair(
        before: blank,
        after: blank,
        counterBefore: 0,
        counterAfter: 1,
        layout: layout,
      );
      expect(proof['verdict'], 'fail');
    });

    test('linux-like ~3.3% diagonal foreign misses probe columns yet can pass 0.95', () {
      final layout = NativeCaptureLayout.fromSemantics(
        imageWidth: 1280,
        imageHeight: 720,
        marker: const AxBounds(left: 0, top: 0, width: 1280, height: 8),
        counter: const AxBounds(left: 24, top: 32, width: 200, height: 56),
      )!;
      final image = img.Image(width: 1280, height: 720);
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 1280; x++) {
          image.setPixelRgba(x, y, 0x22, 0xAA, 0x55, 0xFF);
        }
      }
      paintRealisticTopRightDiagonalForeign(
        image,
        layout: layout,
        foreignFractionOfInterior: 0.033,
      );
      final stripe = analyzeMarkerStripe(image, layout: layout);
      expect(stripe['greenRatio'], greaterThan(0.95));
      expect(
        (stripe['probePoints'] as List).every((p) => (p as Map)['ok'] == 1),
        isTrue,
      );
    });

    test('android-like ~10.1% diagonal foreign fails 0.95 but probes stay green', () {
      final layout = NativeCaptureLayout.fromSemantics(
        imageWidth: 1080,
        imageHeight: 2274,
        marker: const AxBounds(left: 0, top: 0, width: 411, height: 8),
        counter: const AxBounds(left: 24, top: 32, width: 80, height: 56),
      )!;
      final image = img.Image(width: 1080, height: 2274);
      for (var y = 0; y < 21; y++) {
        for (var x = 0; x < 1080; x++) {
          image.setPixelRgba(x, y, 0x22, 0xAA, 0x55, 0xFF);
        }
      }
      paintRealisticTopRightDiagonalForeign(
        image,
        layout: layout,
        foreignFractionOfInterior: 0.101,
      );
      final stripe = analyzeMarkerStripe(image, layout: layout);
      expect(stripe['greenRatio'], lessThan(0.95));
      expect(
        (stripe['probePoints'] as List).every((p) => (p as Map)['ok'] == 1),
        isTrue,
      );
    });

    test('fails when stripe is wrong color', () {
      final image = img.Image(width: 320, height: 240);
      final layout = NativeCaptureLayout.identityForImage(image);
      for (var y = 0; y < layout.markerStripePhysicalPx; y++) {
        for (var x = 0; x < image.width; x++) {
          image.setPixelRgba(x, y, 0xFF, 0x00, 0x00, 0xFF);
        }
      }
      final bytes = _encode(image);
      final proof = analyzeCapturePair(
        before: bytes,
        after: bytes,
        counterBefore: 0,
        counterAfter: 1,
        layout: layout,
      );
      expect(proof['verdict'], 'fail');
      expect(proof['reason'], 'marker_stripe_not_green');
    });

    test('fails when counter ROI unchanged (identical images)', () {
      final (image, layout) = _fixture320(counterGlyph: '0');
      final same = _encode(image);
      final proof = analyzeCapturePair(
        before: same,
        after: same,
        counterBefore: 0,
        counterAfter: 1,
        layout: layout,
      );
      expect(proof['verdict'], 'fail');
      expect(proof['reason'], 'counter_roi_insufficient_delta');
    });

    test('fails when only button region changes (synthetic ripple)', () {
      final (beforeImg, layout) = _fixture320(counterGlyph: '0');
      final afterImg = img.Image.from(beforeImg);
      for (var y = 120; y < 180; y++) {
        for (var x = 40; x < 200; x++) {
          afterImg.setPixelRgba(x, y, 80, 80, 80, 255);
        }
      }
      final proof = analyzeCapturePair(
        before: _encode(beforeImg),
        after: _encode(afterImg),
        counterBefore: 0,
        counterAfter: 1,
        layout: layout,
      );
      expect(proof['verdict'], 'fail');
      expect(proof['reason'], 'counter_roi_insufficient_delta');
    });

    test('fails when semantics counter did not increment', () {
      final (img0, layout) = _fixture320(counterGlyph: '0');
      final (img1, _) = _fixture320(counterGlyph: '1');
      final proof = analyzeCapturePair(
        before: _encode(img0),
        after: _encode(img1),
        counterBefore: 0,
        counterAfter: 0,
        layout: layout,
      );
      expect(proof['verdict'], 'fail');
      expect(proof['reason'], 'counter_not_incremented');
    });
  });

  group('analyzeCliCaptureProof', () {
    test('downscales when driver width > 1024', () {
      final driver = img.Image(width: 1280, height: 720);
      final layout = NativeCaptureLayout.identityForImage(driver);
      for (var y = 0; y < layout.markerStripePhysicalPx; y++) {
        for (var x = 0; x < driver.width; x++) {
          driver.setPixelRgba(x, y, 0x22, 0xAA, 0x55, 0xFF);
        }
      }
      final driverBytes = _encode(driver);
      final cliImg = img.copyResize(
        driver,
        width: 1024,
        height: 576,
        interpolation: img.Interpolation.average,
      );
      final cliBytes = _encode(cliImg);
      final proof = analyzeCliCaptureProof(
        driverUncompressed: driverBytes,
        cliResult: {
          'ok': true,
          'envelope': {
            'ok': true,
            'data': {'images': [base64Encode(cliBytes)]},
          },
        },
        driverLayout: layout,
      );
      expect(proof['verdict'], 'pass');
      expect(proof['compressApplied'], isTrue);
      expect(proof['dimensionsOk'], isTrue);
    });

    test('unchanged dimensions when driver width <= 1024', () {
      final driver = img.Image(width: 800, height: 600);
      final layout = NativeCaptureLayout.identityForImage(driver);
      for (var y = 0; y < layout.markerStripePhysicalPx; y++) {
        for (var x = 0; x < driver.width; x++) {
          driver.setPixelRgba(x, y, 0x22, 0xAA, 0x55, 0xFF);
        }
      }
      final driverBytes = _encode(driver);
      final proof = analyzeCliCaptureProof(
        driverUncompressed: driverBytes,
        cliResult: {
          'ok': true,
          'envelope': {
            'ok': true,
            'data': {'images': [base64Encode(driverBytes)]},
          },
        },
        driverLayout: layout,
      );
      expect(proof['compressApplied'], isFalse);
      expect(proof['dimensionsOk'], isTrue);
      expect(proof['cliWidth'], 800);
    });

    test('fails when downscaled image has no marker stripe', () {
      final driver = img.Image(width: 1280, height: 720);
      final layout = NativeCaptureLayout.identityForImage(driver);
      final driverBytes = _encode(driver);
      final cliImg = img.copyResize(driver, width: 1024, height: 576);
      final cliBytes = _encode(cliImg);
      final proof = analyzeCliCaptureProof(
        driverUncompressed: driverBytes,
        cliResult: {
          'ok': true,
          'envelope': {
            'ok': true,
            'data': {'images': [base64Encode(cliBytes)]},
          },
        },
        driverLayout: layout,
      );
      expect(proof['verdict'], 'fail');
      expect(proof['reason'], 'cli_marker_stripe_missing');
    });
  });

  test('analyzeCapturePair and layout.toEvidenceJson jsonEncode without Records',
      () {
    final (image, layout) = _fixture320(counterGlyph: '0');
    final (afterLayoutImage, _) = _fixture320(counterGlyph: '1');
    final proof = analyzeCapturePair(
      before: _encode(image),
      after: _encode(afterLayoutImage),
      counterBefore: 0,
      counterAfter: 1,
      layout: layout,
    );
    expect(() => jsonEncode(proof), returnsNormally);
    expect(() => jsonEncode(layout.toEvidenceJson()), returnsNormally);
    expect(proof['layout'], layout.toEvidenceJson());
  });
}
