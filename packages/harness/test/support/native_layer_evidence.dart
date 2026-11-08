import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:image/image.dart' as img;
import 'vm_screenshot_grabber_sdk_compat.dart';
import 'package:universal_tooling_runtime/universal_tooling_runtime.dart';

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

Map<String, Object?> analyzePngPair(Uint8List before, Uint8List after) {
  final decodedBefore = img.decodeImage(before);
  final decodedAfter = img.decodeImage(after);
  if (decodedBefore == null || decodedAfter == null) {
    return {
      'verdict': 'fail',
      'reason': 'png_decode_failed',
    };
  }
  if (decodedBefore.width != decodedAfter.width ||
      decodedBefore.height != decodedAfter.height) {
    return {
      'verdict': 'fail',
      'reason': 'dimension_mismatch',
      'widthBefore': decodedBefore.width,
      'widthAfter': decodedAfter.width,
      'heightBefore': decodedBefore.height,
      'heightAfter': decodedAfter.height,
    };
  }
  var diffPixels = 0;
  for (var y = 0; y < decodedBefore.height; y++) {
    for (var x = 0; x < decodedBefore.width; x++) {
      if (decodedBefore.getPixel(x, y) != decodedAfter.getPixel(x, y)) {
        diffPixels++;
      }
    }
  }
  return {
    'verdict': diffPixels > 0 ? 'pass' : 'fail',
    'reason': diffPixels > 0 ? null : 'no_pixel_change',
    'diffPixels': diffPixels,
    'width': decodedBefore.width,
    'height': decodedBefore.height,
    'pngBeforeBytes': before.length,
    'pngAfterBytes': after.length,
  };
}

Map<String, Object?> rendererVerdictFromLogs(LogTap tap, {required String platform}) {
  final text = tap.lines.join('\n');
  final lower = text.toLowerCase();
  final impeller = lower.contains('impeller');
  final skia = lower.contains('skia');
  final vulkan = lower.contains('vulkan');
  final opengl = lower.contains('opengl') || lower.contains('gles');
  String? backend;
  if (impeller) {
    backend = 'impeller';
  } else if (skia) {
    backend = 'skia';
  }
  return {
    'platform': platform,
    'impellerMentioned': impeller,
    'skiaMentioned': skia,
    'vulkanMentioned': vulkan,
    'openglMentioned': opengl,
    'inferredRendererBackend': backend,
    'honestGap': backend == null,
    'logLineCount': tap.lines.length,
  };
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
      ? VmScreenshotGrabber.normalizeWsUri(vmServiceUri).toString()
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

Future<Map<String, Object?>> boundedSettlementReceipt(
  Future<BoundedRunResult>? runFuture,
) async {
  final run = runFuture;
  if (run == null) {
    return {'skipped': true, 'reason': 'no_bounded_run_future'};
  }
  final result = await run;
  return {
    'cause': '${result.cause}',
    'exitCode': result.exitCode,
    'ok': result.ok,
    'physicallySettled': result.physicallySettled,
    'survivors': result.survivors,
    'settlementProblem': result.settlementProblem,
  };
}

Directory harnessRepoRoot() {
  final harnessDir = Directory.current.path.endsWith('harness')
      ? Directory.current
      : Directory('${Directory.current.path}/packages/harness');
  return Directory('${harnessDir.parent.parent.path}');
}

Directory showcaseFlutterTestApp(Directory repoRoot) =>
    Directory('${repoRoot.path}/showcase/flutter_test_app');
