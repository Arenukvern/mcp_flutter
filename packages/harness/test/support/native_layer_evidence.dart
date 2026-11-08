import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:image/image.dart' as img;

const captureBackendFlutterLayerVm = 'flutter_layer_vm_extension';
const captureImplementationAppLayerTree = 'app_layer_tree';

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
  final stripeY1 = 8.clamp(0, decodedBefore.height);
  var stripeDiff = 0;
  for (var y = 0; y < stripeY1; y++) {
    for (var x = 0; x < decodedBefore.width; x++) {
      if (decodedBefore.getPixel(x, y) != decodedAfter.getPixel(x, y)) {
        stripeDiff++;
      }
    }
  }
  return {
    'verdict':
        counterAfter == counterBefore + 1 && stripeDiff == 0 ? 'pass' : 'fail',
    'reason': counterAfter == counterBefore + 1
        ? (stripeDiff == 0 ? null : 'unexpected_stripe_change')
        : 'counter_not_incremented',
    'counterBefore': counterBefore,
    'counterAfter': counterAfter,
    'markerStripeDiffPixels': stripeDiff,
    'width': decodedBefore.width,
    'height': decodedBefore.height,
  };
}

Map<String, Object?> rendererVerdictFromLogs(
  List<String> lines, {
  required String platform,
}) {
  final patterns = <(String backend, RegExp pattern)>[
    (
      'impeller',
      RegExp(
        r'Impeller rendering backend|Using the Impeller rendering backend|embedder_surface_gl_impeller',
        caseSensitive: false,
      ),
    ),
    (
      'impeller',
      RegExp(r'FlutterImpeller', caseSensitive: false),
    ),
    (
      'skia',
      RegExp(
        r'Skia GLES|Skia\s+backend|using\s+Skia',
        caseSensitive: false,
      ),
    ),
    (
      'software',
      RegExp(r'software rendering', caseSensitive: false),
    ),
  ];

  final hits = <Map<String, Object?>>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (final (backend, pattern) in patterns) {
      if (pattern.hasMatch(line)) {
        hits.add({
          'lineIndex': i,
          'backend': backend,
          'sourceLine': line,
          'pattern': pattern.pattern,
        });
      }
    }
  }

  final active = hits.isEmpty ? null : hits.first['backend'] as String;
  return {
    'platform': platform,
    'activeRendererBackend': active,
    'observed': hits.isNotEmpty,
    'hits': hits,
    'honestGap': active == null,
    'logLineCount': lines.length,
  };
}

Future<Process?> startAndroidEngineLogcat({
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
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => sink.add('[logcat] $line'));
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => sink.add('[logcat:err] $line'));
    return process;
  } on Object {
    return null;
  }
}

Future<void> vmHandshake(Uri vmServiceUri) async {
  final client = await VmClient.connect(vmServiceUri);
  await client.dispose();
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
  return {
    'ok': envelope['ok'] == true,
    'captureMode': data?['captureMode'],
    'captureBackend': data?['captureBackend'],
    'captureImplementation': data?['captureImplementation'],
    'imageCount': (data?['images'] as List?)?.length ?? 0,
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
