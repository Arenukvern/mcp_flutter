import 'dart:io';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

Future<void> main(List<String> args) async {
  final ref = args.first;
  final client = await VmClient.connect(Uri.parse(Platform.environment['LA_VM_URI']!));
  await client
      .callExtension(ToolkitExtensions.tap, args: {'ref': ref})
      .timeout(const Duration(seconds: 25));
  await Future<void>.delayed(const Duration(milliseconds: 1200));
  final tree = await client
      .callExtension(ToolkitExtensions.snapshot, args: const {})
      .timeout(const Duration(seconds: 25));
  final nodes = (tree['nodes']! as List<Object?>)
      .whereType<Map<String, Object?>>()
      .toList();
  for (final n in nodes) {
    if (n['type'] == 'button' && n['visibleInViewport'] == true) {
      final c = n['center'] as Map<String, Object?>?;
      final l = n['label'].toString();
      stdout.writeln(
          '${n['ref']} y=${c?['y']} x=${c?['x']} label=${l.substring(0, l.length.clamp(0, 40))}');
    }
  }
  exit(0);
}
