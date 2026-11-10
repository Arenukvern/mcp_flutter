import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:image/image.dart' as img;

import 'bounded_subprocess_stop.dart';
import 'native_layer_capture_layout.dart';

const captureBackendFlutterLayerVm = 'flutter_layer_vm_extension';
const captureImplementationAppLayerTree = 'app_layer_tree';

/// Fixture marker stripe (see [kMarkerStripe] in fixture `main.dart`).
const int kMarkerStripeArgb = 0xFF22AA55;
const int kMarkerStripeHeightPx = 8;

/// Minimum changed pixels in counter ROI after 0→1 (excludes tiny noise).
const int kMinCounterRoiDiffPixels = 12;

Directory nativeCaptureArtifactDir() {
  final fromEnv = Platform.environment['NATIVE_CAPTURE_ARTIFACT_DIR'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return Directory(fromEnv)..createSync(recursive: true);
  }
  return Directory.systemTemp.createTempSync('native_flutter_layer_');
}

Future<void> writeJsonArtifact(Directory dir, String name, Object? value) async {
  await File('${dir.path}/$name').writeAsString(
    const JsonEncoder.withIndent('  ').convert(value),
  );
}

Future<Uint8List> writePng(Directory dir, String name, Uint8List bytes) async {
  await File('${dir.path}/$name').writeAsBytes(bytes);
  return bytes;
}

Future<int> counterFromDriver(ToolkitDriver driver) async {
  final nodes = (await driver.snapshot()).nodes.toList();
  for (final node in nodes) {
    if (node.attributes['identifier'] == 'native_layer_counter_value') {
      final parsed = int.tryParse(node.value ?? node.name ?? '');
      if (parsed != null) return parsed;
    }
  }
  throw StateError('native_layer_counter_value not found');
}

Future<void> tapIncrementButton(ToolkitDriver driver) async {
  final nodes = (await driver.snapshot()).nodes.toList();
  for (final node in nodes) {
    if (node.attributes['identifier'] == 'native_layer_increment_button') {
      final ref = node.attributes['ref'];
      if (ref != null) {
        await driver.perform(ClickAction(css: ref));
        return;
      }
    }
  }
  throw StateError('native_layer_increment_button ref not found');
}

int _pixelArgb(img.Image image, int x, int y) {
  final p = image.getPixel(x, y);
  return (p.a.toInt() << 24) |
      (p.r.toInt() << 16) |
      (p.g.toInt() << 8) |
      p.b.toInt();
}

bool _isMarkerGreenArgb(int argb, {bool resamplingTolerant = false}) {
  final a = (argb >> 24) & 0xFF;
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  if (a != 0xFF) return false;
  if (!resamplingTolerant) {
    return r == 0x22 && g == 0xAA && b == 0x55;
  }
  const tol = 24;
  return (r - 0x22).abs() <= tol &&
      (g - 0xAA).abs() <= tol &&
      (b - 0x55).abs() <= tol;
}

/// Samples the top marker stripe for the fixture green (#22AA55).
Map<String, Object?> analyzeMarkerStripe(
  img.Image image, {
  required NativeCaptureLayout layout,
  bool resamplingTolerant = false,
  double minGreenRatio = 0.95,
}) {
  final stripeTop = layout.markerStripePhysicalTop;
  final stripeLeft = layout.markerStripePhysicalLeft;
  final stripeW = layout.markerStripePhysicalWidth.clamp(1, image.width - stripeLeft);
  final stripeH = layout.markerStripePhysicalPx.clamp(1, image.height - stripeTop);
  var samples = 0;
  var greenHits = 0;
  for (var y = stripeTop; y < stripeTop + stripeH; y++) {
    for (var x = stripeLeft; x < stripeLeft + stripeW; x++) {
      samples++;
      if (_isMarkerGreenArgb(
        _pixelArgb(image, x, y),
        resamplingTolerant: resamplingTolerant,
      )) {
        greenHits++;
      }
    }
  }
  final probeYs = <int>{
    stripeTop,
    if (stripeH > 2) stripeTop + stripeH ~/ 2,
    if (stripeH > 1) stripeTop + stripeH - 1,
  }.where((y) => y >= stripeTop && y < stripeTop + stripeH).toList();
  final probeXs = [
    stripeLeft,
    stripeLeft + stripeW ~/ 2,
    stripeLeft + stripeW - 1,
  ];
  final probePoints = <Map<String, int>>[];
  var probesOk = true;
  for (final y in probeYs) {
    for (final x in probeXs) {
      final ok = _isMarkerGreenArgb(
        _pixelArgb(image, x, y),
        resamplingTolerant: resamplingTolerant,
      );
      probePoints.add({'x': x, 'y': y, 'ok': ok ? 1 : 0});
      if (!ok) probesOk = false;
    }
  }
  final ratio = samples == 0 ? 0.0 : greenHits / samples;
  final interior = _stripeInteriorExactGreenRatio(
    image,
    stripeTop: stripeTop,
    stripeLeft: stripeLeft,
    stripeW: stripeW,
    stripeH: stripeH,
  );
  final interiorSamples = interior['samples'] as int;
  final interiorGreenHits = interior['greenHits'] as int;
  final interiorExactOk =
      interiorSamples > 0 && interiorGreenHits == interiorSamples;

  return {
    'stripeHeightPx': stripeH,
    'stripeTopPx': stripeTop,
    'stripeLeftPx': stripeLeft,
    'stripeWidthPx': stripeW,
    'samples': samples,
    'greenHits': greenHits,
    'greenRatio': ratio,
    'interiorExactGreenRatio': interior['ratio'],
    'interiorSamples': interiorSamples,
    'interiorExactGreenHits': interiorGreenHits,
    'interiorExactOk': interiorExactOk,
    'probePoints': probePoints,
    'ok': probesOk && samples > 0 && ratio >= minGreenRatio,
  };
}

/// Driver `compress_false` captures require solid interior (#22AA55 exact).
const double kDriverInteriorExactGreenRatio = 1.0;

/// Full-resolution exact marker color, excluding probe rows/columns (edge handling).
Map<String, Object?> _stripeInteriorExactGreenRatio(
  img.Image image, {
  required int stripeTop,
  required int stripeLeft,
  required int stripeW,
  required int stripeH,
}) {
  final probeXs = {
    stripeLeft,
    stripeLeft + stripeW ~/ 2,
    stripeLeft + stripeW - 1,
  };
  final probeYs = {
    stripeTop,
    if (stripeH > 2) stripeTop + stripeH ~/ 2,
    if (stripeH > 1) stripeTop + stripeH - 1,
  };
  var samples = 0;
  var greenHits = 0;
  for (var y = stripeTop; y < stripeTop + stripeH; y++) {
    for (var x = stripeLeft; x < stripeLeft + stripeW; x++) {
      if (probeXs.contains(x) || probeYs.contains(y)) continue;
      samples++;
      if (_isMarkerGreenArgb(_pixelArgb(image, x, y))) greenHits++;
    }
  }
  return {
    'samples': samples,
    'greenHits': greenHits,
    'ratio': samples == 0 ? 0.0 : greenHits / samples,
  };
}

/// Diagonal top-right overlay avoiding probe columns (empirical Linux/Android densities).
void paintRealisticTopRightDiagonalForeign(
  img.Image image, {
  required NativeCaptureLayout layout,
  required double foreignFractionOfInterior,
  int argb = 0xFF7A3624,
}) {
  final top = layout.markerStripePhysicalTop;
  final left = layout.markerStripePhysicalLeft;
  final w = layout.markerStripePhysicalWidth.clamp(1, image.width - left);
  final h = layout.markerStripePhysicalPx.clamp(1, image.height - top);
  final probeXs = {left, left + w ~/ 2, left + w - 1};
  final probeYs = {
    top,
    if (h > 2) top + h ~/ 2,
    if (h > 1) top + h - 1,
  };
  final candidates = <(int x, int y, int rank)>[];
  for (var y = top; y < top + h; y++) {
    for (var x = left; x < left + w; x++) {
      if (probeXs.contains(x) || probeYs.contains(y)) continue;
      final rank = (left + w - x) + (y - top);
      candidates.add((x, y, rank));
    }
  }
  candidates.sort((a, b) => a.$3.compareTo(b.$3));
  final foreignCount = (candidates.length * foreignFractionOfInterior).round();
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  for (var i = 0; i < foreignCount && i < candidates.length; i++) {
    final (x, y, _) = candidates[i];
    image.setPixelRgba(x, y, r, g, b, 255);
  }
}

/// Counts exact vs tolerant-green vs foreign pixels in the semantics stripe ROI.
Map<String, Object?> analyzeMarkerStripeForensics(
  img.Image image, {
  required NativeCaptureLayout layout,
}) {
  final stripe = analyzeMarkerStripe(image, layout: layout);
  final top = layout.markerStripePhysicalTop;
  final left = layout.markerStripePhysicalLeft;
  final w = layout.markerStripePhysicalWidth.clamp(1, image.width - left);
  final h = layout.markerStripePhysicalPx.clamp(1, image.height - top);
  var exact = 0, tolerant = 0, foreign = 0;
  final foreignColors = <String, int>{};
  for (var y = top; y < top + h; y++) {
    for (var x = left; x < left + w; x++) {
      final argb = _pixelArgb(image, x, y);
      if (_isMarkerGreenArgb(argb)) {
        exact++;
      } else if (_isMarkerGreenArgb(argb, resamplingTolerant: true)) {
        tolerant++;
      } else {
        foreign++;
        final r = (argb >> 16) & 0xFF;
        final g = (argb >> 8) & 0xFF;
        final b = argb & 0xFF;
        final a = (argb >> 24) & 0xFF;
        final k = '$r,$g,$b,$a';
        foreignColors[k] = (foreignColors[k] ?? 0) + 1;
      }
    }
  }
  final rankedForeign = foreignColors.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {
    'layout': layout.toEvidenceJson(),
    'stripeAnalysis': stripe,
    'exactGreenPixels': exact,
    'tolerantOnlyPixels': tolerant,
    'foreignPixels': foreign,
    'topForeignColors': rankedForeign
        .take(8)
        .map((e) => {'rgba': e.key, 'count': e.value})
        .toList(),
  };
}

int counterTextRoiDiffPixels(
  img.Image before,
  img.Image after,
  NativeCaptureLayout layout,
) {
  final (left, top, width, height) = layout.counterTextPhysicalRoi;
  final rLeft = left.clamp(0, before.width - 1);
  final rTop = top.clamp(0, before.height - 1);
  final rWidth = width.clamp(1, before.width - rLeft);
  final rHeight = height.clamp(1, before.height - rTop);
  var diff = 0;
  for (var y = rTop; y < rTop + rHeight; y++) {
    for (var x = rLeft; x < rLeft + rWidth; x++) {
      if (before.getPixel(x, y) != after.getPixel(x, y)) diff++;
    }
  }
  return diff;
}

Map<String, Object?> analyzeCapturePair({
  required Uint8List before,
  required Uint8List after,
  required int counterBefore,
  required int counterAfter,
  required NativeCaptureLayout layout,
}) {
  final decodedBefore = img.decodeImage(before);
  final decodedAfter = img.decodeImage(after);
  if (decodedBefore == null || decodedAfter == null) {
    return {'verdict': 'fail', 'reason': 'png_decode_failed'};
  }
  if (decodedBefore.width != decodedAfter.width ||
      decodedBefore.height != decodedAfter.height) {
    return {
      'verdict': 'fail',
      'reason': 'dimension_mismatch',
      'widthBefore': decodedBefore.width,
      'heightBefore': decodedBefore.height,
      'widthAfter': decodedAfter.width,
      'heightAfter': decodedAfter.height,
    };
  }

  final stripeBefore = analyzeMarkerStripe(decodedBefore, layout: layout);
  final stripeAfter = analyzeMarkerStripe(decodedAfter, layout: layout);
  final counterRoiDiff = counterTextRoiDiffPixels(
    decodedBefore,
    decodedAfter,
    layout,
  );

  final counterOk = counterAfter == counterBefore + 1;
  final stripeOk = stripeBefore['ok'] == true && stripeAfter['ok'] == true;
  final interiorBeforeOk = stripeBefore['interiorExactOk'] == true;
  final interiorAfterOk = stripeAfter['interiorExactOk'] == true;
  final interiorExactOk = interiorBeforeOk && interiorAfterOk;
  final roiOk = counterRoiDiff >= kMinCounterRoiDiffPixels;

  String? reason;
  if (!counterOk) {
    reason = 'counter_not_incremented';
  } else if (!stripeOk) {
    reason = 'marker_stripe_not_green';
  } else if (!interiorExactOk) {
    reason = 'marker_stripe_interior_not_exact';
  } else if (!roiOk) {
    reason = 'counter_roi_insufficient_delta';
  }

  return {
    'verdict':
        counterOk && stripeOk && interiorExactOk && roiOk ? 'pass' : 'fail',
    'interiorExactInvariant': 'driver_compress_false_interior_exact_1.0',
    'reason': reason,
    'counterBefore': counterBefore,
    'counterAfter': counterAfter,
    'counterRoiDiffPixels': counterRoiDiff,
    'markerStripeBefore': stripeBefore,
    'markerStripeAfter': stripeAfter,
    'width': decodedBefore.width,
    'height': decodedBefore.height,
    'layout': layout.toEvidenceJson(),
  };
}

/// Affirmative backend startup lines only — not bare source filenames.
final _impellerAffirmative = RegExp(
  r'Using the Impeller rendering backend\s*\([^)]+\)',
  caseSensitive: false,
);

final _skiaAffirmative = RegExp(
  r'Using the Skia rendering backend(?:\s*\([^)]+\))?',
  caseSensitive: false,
);

Map<String, Object?> rendererVerdictFromLogs(
  List<String> lines, {
  required String platform,
}) {
  final hits = <Map<String, Object?>>[];
  String? active;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_impellerAffirmative.hasMatch(line)) {
      hits.add({
        'lineIndex': i,
        'backend': 'impeller',
        'kind': 'affirmative_startup',
        'sourceLine': line,
      });
      active ??= 'impeller';
    } else if (_skiaAffirmative.hasMatch(line)) {
      hits.add({
        'lineIndex': i,
        'backend': 'skia',
        'kind': 'affirmative_startup',
        'sourceLine': line,
      });
      active ??= 'skia';
    }
  }

  final accepted = active != null;
  final expectedBackend = platform == 'android' ? 'impeller' : null;
  final platformAccepted = switch (platform) {
    'android' => active == 'impeller',
    'linux' => accepted,
    _ => accepted,
  };
  return {
    'platform': platform,
    'activeRendererBackend': active ?? 'unknown',
    'rendererAccepted': accepted,
    'platformRendererAccepted': platformAccepted,
    'expectedRendererBackend': expectedBackend,
    'observed': hits.isNotEmpty,
    'hits': hits,
    'honestGap': !accepted,
    'logLineCount': lines.length,
  };
}

/// Owned adb logcat stream for renderer / engine evidence (not fire-and-forget).
final class AndroidEngineLogcatSession {
  AndroidEngineLogcatSession._(
    this._process,
    this._stdoutDrain,
    this._stderrDrain,
  );

  final Process _process;
  final Future<void> _stdoutDrain;
  final Future<void> _stderrDrain;
  SubprocessStopVerdict? lastStopVerdict;

  int get pid => _process.pid;

  static Future<AndroidEngineLogcatSession> start({
    required String deviceId,
    required LogTap sink,
    String adbBin = 'adb',
  }) async {
    try {
      final clear = await Process.run(adbBin, ['-s', deviceId, 'logcat', '-c']);
      if (clear.exitCode != 0) {
        throw StateError(
          'adb logcat -c failed (${clear.exitCode}): ${clear.stderr}',
        );
      }
      final process = await Process.start(adbBin, [
        '-s',
        deviceId,
        'logcat',
        '-v',
        'time',
      ]);
      final stdoutDrain = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) => sink.add('[logcat] $line'))
          .drain<void>();
      final stderrDrain = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) => sink.add('[logcat:err] $line'))
          .drain<void>();
      return AndroidEngineLogcatSession._(process, stdoutDrain, stderrDrain);
    } on Object catch (error, stack) {
      Error.throwWithStackTrace(
        StateError('adb logcat start failed for $deviceId: $error'),
        stack,
      );
    }
  }

  Future<SubprocessStopVerdict> stop() async {
    final verdict = await stopOwnedSubprocess(
      _process,
      stdoutDrain: _stdoutDrain,
      stderrDrain: _stderrDrain,
    );
    lastStopVerdict = verdict;
    if (!verdict.settled) {
      throw StateError(
        'adb logcat stop did not settle: ${verdict.toJson()}',
      );
    }
    return verdict;
  }
}

Future<void> vmHandshake(Uri vmServiceUri) async {
  final client = await VmClient.connect(vmServiceUri);
  await client.dispose();
}

Uint8List? cliPrimaryPngBytes(Map<String, Object?> cliResult) {
  if (cliResult['ok'] != true) return null;
  final envelope = cliResult['envelope'];
  if (envelope is! Map) return null;
  final data = envelope['data'];
  if (data is! Map) return null;
  final images = data['images'];
  if (images is! List || images.isEmpty) return null;
  final first = images.first;
  if (first is! String || first.isEmpty) return null;
  return base64Decode(first);
}

/// Min green ratio for CLI captures after axis-aligned downscale (~0.8×).
///
/// Box/average filtering mixes the 8 px stripe with neighbors; the worst row
/// is the bottom stripe edge. With proportional stripe height \(h\) and
/// resampling-tolerant `#22AA55` (±24 per channel), observed green hits stay
/// above this floor for the fixture’s flat stripe — see
/// `analyzeCliCaptureProof` unit tests (not a product-wide loosening).
const double kCliCompressMinGreenRatio = 0.70;

Map<String, Object?> analyzeCliCaptureProof({
  required Uint8List driverUncompressed,
  required Map<String, Object?> cliResult,
  required NativeCaptureLayout driverLayout,
}) {
  final cliBytes = cliPrimaryPngBytes(cliResult);
  if (cliBytes == null) {
    return {'verdict': 'fail', 'reason': 'cli_no_decodable_image'};
  }
  final driverImg = img.decodeImage(driverUncompressed);
  final cliImg = img.decodeImage(cliBytes);
  if (driverImg == null || cliImg == null) {
    return {'verdict': 'fail', 'reason': 'cli_or_driver_png_decode_failed'};
  }
  final widthScale = cliImg.width / driverImg.width;
  final heightScale = cliImg.height / driverImg.height;
  final bool dimensionsOk;
  if (driverImg.width <= kCliCompressMaxWidthPx) {
    dimensionsOk =
        cliImg.width == driverImg.width && cliImg.height == driverImg.height;
  } else {
    final expectedCliW = kCliCompressMaxWidthPx;
    final expectedCliH = (expectedCliW / (driverImg.width / driverImg.height))
        .round();
    dimensionsOk = cliImg.width == expectedCliW && cliImg.height == expectedCliH;
  }
  final cliLayout = driverLayout.forRescaledImage(cliImg.width, cliImg.height);
  final stripeCli = analyzeMarkerStripe(
    cliImg,
    layout: cliLayout,
    resamplingTolerant: driverImg.width > kCliCompressMaxWidthPx,
    minGreenRatio: kCliCompressMinGreenRatio,
  );
  String? reason;
  if (!dimensionsOk) {
    reason = 'cli_downscale_dimensions_invalid';
  } else if (stripeCli['ok'] != true) {
    reason = 'cli_marker_stripe_missing';
  }
  return {
    'verdict': reason == null ? 'pass' : 'fail',
    'reason': reason,
    'driverWidth': driverImg.width,
    'driverHeight': driverImg.height,
    'cliWidth': cliImg.width,
    'cliHeight': cliImg.height,
    'widthScale': widthScale,
    'heightScale': heightScale,
    'cliBytes': cliBytes.length,
    'driverBytes': driverUncompressed.length,
    'markerStripeCli': stripeCli,
    // Observed for this deterministic fixture — PNG size is not globally monotonic.
    'compressSmallerThanDriver': cliBytes.length < driverUncompressed.length,
    'dimensionsOk': dimensionsOk,
    'compressMaxWidthPx': kCliCompressMaxWidthPx,
    'compressApplied': driverImg.width > kCliCompressMaxWidthPx,
  };
}

Future<Map<String, Object?>> runToolkitCliGetScreenshots({
  required Directory repoRoot,
  required Uri vmServiceUri,
}) async {
  final serverDir = Directory('${repoRoot.path}/mcp_server_dart');
  final ws = vmServiceUri.scheme == 'http'
      ? canonicalVmServiceWsUri(vmServiceUri).toString()
      : vmServiceUri.toString();
  final result = await Process.run(
    'dart',
    [
      'run',
      'bin/flutter_mcp_toolkit.dart',
      '--vm-service-uri',
      ws,
      'exec',
      '--name',
      'get_screenshots',
      '--args',
      jsonEncode({
        'connection': {'uri': ws},
        'compress': true,
        'mode': 'flutter_layer',
      }),
    ],
    workingDirectory: serverDir.path,
  );
  if (result.exitCode != 0) {
    return {
      'ok': false,
      'exitCode': result.exitCode,
      'stdout': '${result.stdout}',
      'stderr': '${result.stderr}',
    };
  }
  final stdoutText = (result.stdout as String).trim();
  if (stdoutText.isEmpty) {
    return {'ok': false, 'error': 'empty_stdout'};
  }
  final envelope = jsonDecode(stdoutText) as Map<String, dynamic>;
  final data = (envelope['data'] as Map?)?.cast<String, Object?>();
  final png = cliPrimaryPngBytes({
    'ok': envelope['ok'] == true,
    'envelope': envelope,
  });
  return {
    'ok': envelope['ok'] == true,
    'captureMode': data?['captureMode'],
    'captureBackend': data?['captureBackend'],
    'captureImplementation': data?['captureImplementation'],
    'imageCount': (data?['images'] as List?)?.length ?? 0,
    'cliDecodedBytes': png?.length,
    'envelope': envelope,
  };
}

Directory harnessRepoRoot() {
  final harnessDir = Directory.current.path.endsWith('harness')
      ? Directory.current
      : Directory('${Directory.current.path}/packages/harness');
  return harnessDir.parent.parent;
}

Directory nativeCaptureFixtureApp(Directory repoRoot) =>
    Directory('${repoRoot.path}/showcase/native_layer_capture_fixture');
