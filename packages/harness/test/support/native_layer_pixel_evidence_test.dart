@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'native_layer_evidence.dart';

Uint8List _encode(img.Image image) => Uint8List.fromList(img.encodePng(image));

img.Image _fixtureLike({required String counterGlyph}) {
  final image = img.Image(width: 320, height: 240);
  for (var y = 0; y < kMarkerStripeHeightPx; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, 0x22, 0xAA, 0x55, 0xFF);
    }
  }
  final roi = counterRoiNorm(image);
  final left = roi.$1.round();
  final top = roi.$2.round() + 20;
  img.drawString(
    image,
    counterGlyph,
    font: img.arial24,
    x: left,
    y: top,
    color: img.ColorRgba8(0, 0, 0, 255),
  );
  if (counterGlyph == '1') {
    for (var y = roi.$2.round(); y < roi.$2.round() + 40; y++) {
      for (var x = left + 60; x < left + 80; x++) {
        image.setPixelRgba(x, y, 40, 40, 40, 255);
      }
    }
  }
  return image;
}

void main() {
  group('analyzeCapturePair', () {
    test('passes on green stripe + counter ROI delta when semantics counter +1', () {
      final before = _encode(_fixtureLike(counterGlyph: '0'));
      final after = _encode(_fixtureLike(counterGlyph: '1'));
      final proof = analyzeCapturePair(
        before: before,
        after: after,
        counterBefore: 0,
        counterAfter: 1,
      );
      expect(proof['verdict'], 'pass');
      expect(proof['counterRoiDiffPixels'], greaterThanOrEqualTo(kMinCounterRoiDiffPixels));
    });

    test('fails on identical blank PNGs despite fake counter semantics', () {
      final blank = _encode(img.Image(width: 320, height: 240));
      final proof = analyzeCapturePair(
        before: blank,
        after: blank,
        counterBefore: 0,
        counterAfter: 1,
      );
      expect(proof['verdict'], 'fail');
    });

    test('fails when stripe is wrong color', () {
      final bad = img.Image(width: 320, height: 240);
      for (var y = 0; y < kMarkerStripeHeightPx; y++) {
        for (var x = 0; x < bad.width; x++) {
          bad.setPixelRgba(x, y, 0xFF, 0x00, 0x00, 0xFF);
        }
      }
      final bytes = _encode(bad);
      final proof = analyzeCapturePair(
        before: bytes,
        after: bytes,
        counterBefore: 0,
        counterAfter: 1,
      );
      expect(proof['verdict'], 'fail');
      expect(proof['reason'], 'marker_stripe_not_green');
    });

    test('fails when counter ROI unchanged (ripple-only style)', () {
      final same = _encode(_fixtureLike(counterGlyph: '0'));
      final proof = analyzeCapturePair(
        before: same,
        after: same,
        counterBefore: 0,
        counterAfter: 1,
      );
      expect(proof['verdict'], 'fail');
      expect(proof['reason'], 'counter_roi_insufficient_delta');
    });

    test('fails when semantics counter did not increment', () {
      final before = _encode(_fixtureLike(counterGlyph: '0'));
      final after = _encode(_fixtureLike(counterGlyph: '1'));
      final proof = analyzeCapturePair(
        before: before,
        after: after,
        counterBefore: 0,
        counterAfter: 0,
      );
      expect(proof['verdict'], 'fail');
      expect(proof['reason'], 'counter_not_incremented');
    });
  });
}
