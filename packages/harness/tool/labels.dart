import 'dart:io';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

Future<void> main(List<String> args) async {
  final client = await VmClient.connect(Uri.parse(Platform.environment['LA_VM_URI']!));
  final tree = await client
      .callExtension(ToolkitExtensions.snapshot, args: const {})
      .timeout(const Duration(seconds: 25));
  final nodes = (tree['nodes']! as List<Object?>)
      .whereType<Map<String, Object?>>()
      .where((n) => n['visibleInViewport'] == true)
      .toList();
  for (final n in nodes) {
    final c = n['center'] as Map<String, Object?>?;
    final l = n['label'].toString().replaceAll('\n', ' ');
    stdout.writeln(
        '${n['ref']} ${n['type']} y=${c?['y']} x=${c?['x']} "${l.substring(0, l.length.clamp(0, 44))}"');
  }
  exit(0);
}
