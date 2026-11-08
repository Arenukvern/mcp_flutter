import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:universal_automation_interface/universal_automation_interface.dart';

Future<void> main(List<String> args) async {
  final uriText = args.isNotEmpty
      ? args.first
      : Platform.environment['LA_VM_URI'];
  final outDir = args.length > 1 ? args[1] : '/tmp/native_layer_proof';
  if (uriText == null || uriText.isEmpty) {
    stderr.writeln(
      'usage: dart run native_layer_proof.dart <vmServiceWsUri> [outDir]',
    );
    exit(2);
  }
  Directory(outDir).createSync(recursive: true);

  final client = await VmClient.connect(Uri.parse(uriText));
  final driver = ToolkitDriver(client);

  Future<Uint8List> shot(String tag) async {
    final bytes = await driver.screenshot().timeout(const Duration(seconds: 30));
    await File('$outDir/$tag.png').writeAsBytes(bytes);
    return bytes;
  }

  final before = await shot('before_tap');
  await driver.perform(const ClickAction(name: 'Increment'));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  final after = await shot('after_tap');

  final analysis = _analyzePair(before, after);
  await File('$outDir/harness_proof.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(analysis),
  );
  stdout.writeln(jsonEncode(analysis));

  if (analysis['verdict'] != 'pass') {
    stderr.writeln('native_layer_proof failed: ${analysis['reason']}');
    exit(3);
  }
  exit(0);
}

Map<String, Object?> _analyzePair(Uint8List before, Uint8List after) {
  final b0 = _probePng(before);
  final b1 = _probePng(after);
  if (b0['pngValid'] != true || b1['pngValid'] != true) {
    return {
      'verdict': 'fail',
      'reason': 'png_probe_failed',
      'before': b0,
      'after': b1,
      'captureImplementation': 'app_layer_tree_via_view_screenshots',
    };
  }
  final w = b0['width']! as int;
  final h = b0['height']! as int;
  if (w < 64 || h < 64) {
    return {
      'verdict': 'fail',
      'reason': 'fixture_too_small_for_marker',
      'width': w,
      'height': h,
    };
  }
  final diffBytes = _byteDiffCount(before, after);
  final changed = diffBytes > 64;
  return {
    'verdict': changed ? 'pass' : 'fail',
    'reason': changed ? null : 'no_visual_change_after_increment',
    'pngBeforeBytes': before.length,
    'pngAfterBytes': after.length,
    'width': w,
    'height': h,
    'rawByteDiffCount': diffBytes,
    'captureImplementation': 'app_layer_tree_via_view_screenshots',
    'uiAction': 'tap Increment',
    'markerExpectation': 'Count label changes after increment',
  };
}

Map<String, Object?> _probePng(Uint8List b) {
  if (b.length < 24 ||
      b[0] != 0x89 ||
      b[1] != 0x50 ||
      b[2] != 0x4e ||
      b[3] != 0x47) {
    return {'pngValid': false};
  }
  final w = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
  final h = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
  return {'pngValid': true, 'width': w, 'height': h, 'pngBytes': b.length};
}

int _byteDiffCount(Uint8List a, Uint8List b) {
  final n = a.length < b.length ? a.length : b.length;
  var d = 0;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) d++;
  }
  d += (a.length - n).abs() + (b.length - n).abs();
  return d;
}
