import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

Future<void> main() async {
  final client = await VmClient.connect(Uri.parse(Platform.environment['LA_VM_URI']!));
  final res = await client
      .callExtension(ToolkitExtensions.snapshot, args: const {})
      .timeout(const Duration(seconds: 25));
  final nodes = (res['nodes']! as List<Object?>).whereType<Map<String, Object?>>().toList();
  for (final n in nodes) {
    if (n['type'] == 'button') {
      final center = n['center'] as Map<String, Object?>?;
      stdout.writeln(
          '${n['ref']} center=$center label=${n['label']} tooltip=${n['tooltip']} visible=${n['visibleInViewport']}');
    }
  }
  exit(0);
}
