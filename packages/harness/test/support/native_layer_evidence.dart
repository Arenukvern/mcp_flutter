import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:image/image.dart' as img;

const captureBackendFlutterLayerVm = 'flutter_layer_vm_extension';
const captureImplementationAppLayerTree = 'app_layer_tree';

/// Fixture marker stripe (see [kMarkerStripe] in fixture `main.dart`).
const int kMarkerStripeArgb = 0xFF22AA55;
const int kMarkerStripeHeightPx = 8;

/// Counter text region below stripe (fraction of decoded capture dimensions).
(double left, double top, double width, double height) counterRoiNorm(
  img.Image image,
) {
  return (
    image.width * 0.20,
    kMarkerStripeHeightPx + image.height * 0.04,
    image.width * 0.60,
    image.height * 0.22,
  );
}

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

bool _isMarkerGreenArgb(int argb) {
  final a = (argb >> 24) & 0xFF;
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return a == 0xFF && r == 0x22 && g == 0xAA && b == 0x55;
}

/// Samples the top marker stripe for the fixture green (#22AA55).
Map<String, Object?> analyzeMarkerStripe(img.Image image) {
  final stripeH = kMarkerStripeHeightPx.clamp(0, image.height);
  var samples = 0;
  var greenHits = 0;
  for (var y = 0; y < stripeH; y++) {
    for (var x = 0; x < image.width; x++) {
      samples++;
      if (_isMarkerGreenArgb(_pixelArgb(image, x, y))) greenHits++;
    }
  }
  final probeYs = [1, stripeH ~/ 2, stripeH - 1]
      .where((y) => y >= 0 && y < stripeH)
      .toList();
  final probePoints = <Map<String, int>>[];
  var probesOk = true;
  for (final y in probeYs) {
    for (final x in [0, image.width ~/ 2, image.width - 1]) {
      final ok = _isMarkerGreenArgb(_pixelArgb(image, x, y));
      probePoints.add({'x': x, 'y': y, 'ok': ok ? 1 : 0});
      if (!ok) probesOk = false;
    }
  }
  final ratio = samples == 0 ? 0.0 : greenHits / samples;
  return {
    'samples': samples,
    'greenHits': greenHits,
    'greenRatio': ratio,
    'probePoints': probePoints,
    'ok': probesOk && samples > 0 && ratio >= 0.95,
  };
}

int counterTextRoiDiffPixels(img.Image before, img.Image after) {
  final norm = counterRoiNorm(before);
  final left = norm.$1.round().clamp(0, before.width - 1);
  final top = norm.$2.round().clamp(0, before.height - 1);
  final width = norm.$3.round().clamp(1, before.width - left);
  final height = norm.$4.round().clamp(1, before.height - top);
  var diff = 0;
  for (var y = top; y < top + height; y++) {
    for (var x = left; x < left + width; x++) {
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

  final stripeBefore = analyzeMarkerStripe(decodedBefore);
  final stripeAfter = analyzeMarkerStripe(decodedAfter);
  final counterRoiDiff = counterTextRoiDiffPixels(decodedBefore, decodedAfter);

  final counterOk = counterAfter == counterBefore + 1;
  final stripeOk = stripeBefore['ok'] == true && stripeAfter['ok'] == true;
  final roiOk = counterRoiDiff >= kMinCounterRoiDiffPixels;

  String? reason;
  if (!counterOk) {
    reason = 'counter_not_incremented';
  } else if (!stripeOk) {
    reason = 'marker_stripe_not_green';
  } else if (!roiOk) {
    reason = 'counter_roi_insufficient_delta';
  }

  return {
    'verdict': counterOk && stripeOk && roiOk ? 'pass' : 'fail',
    'reason': reason,
    'counterBefore': counterBefore,
    'counterAfter': counterAfter,
    'counterRoiDiffPixels': counterRoiDiff,
    'markerStripeBefore': stripeBefore,
    'markerStripeAfter': stripeAfter,
    'width': decodedBefore.width,
    'height': decodedBefore.height,
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
  return {
    'platform': platform,
    'activeRendererBackend': active ?? 'unknown',
    'rendererAccepted': accepted,
    'observed': hits.isNotEmpty,
    'hits': hits,
    'honestGap': !accepted,
    'logLineCount': lines.length,
  };
}

/// Owned adb logcat stream for renderer / engine evidence (not fire-and-forget).
final class AndroidEngineLogcatSession {
  AndroidEngineLogcatSession._(this._process, this._done);

  final Process _process;
  final Future<void> _done;

  static Future<AndroidEngineLogcatSession?> start({
    required String deviceId,
    required LogTap sink,
  }) async {
    try {
      await Process.run('adb', ['-s', deviceId, 'logcat', '-c']);
      final process = await Process.start('adb', [
        '-s',
        deviceId,
        'logcat',
        '-v',
        'time',
      ]);
      final stdoutDone = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) => sink.add('[logcat] $line'))
          .drain<void>();
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) => sink.add('[logcat:err] $line'))
          .drain<void>();
      final done = Future.wait([stdoutDone, stderrDone]);
      return AndroidEngineLogcatSession._(process, done);
    } on Object {
      return null;
    }
  }

  Future<void> stop() async {
    _process.kill();
    await _done.timeout(const Duration(seconds: 3), onTimeout: () {});
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

Map<String, Object?> analyzeCliCaptureProof({
  required Uint8List driverUncompressed,
  required Map<String, Object?> cliResult,
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
  final stripeCli = analyzeMarkerStripe(cliImg);
  return {
    'verdict': stripeCli['ok'] == true ? 'pass' : 'fail',
    'reason': stripeCli['ok'] == true ? null : 'cli_marker_stripe_missing',
    'driverWidth': driverImg.width,
    'driverHeight': driverImg.height,
    'cliWidth': cliImg.width,
    'cliHeight': cliImg.height,
    'cliBytes': cliBytes.length,
    'driverBytes': driverUncompressed.length,
    'markerStripeCli': stripeCli,
    'compressSmallerThanDriver': cliBytes.length < driverUncompressed.length,
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
