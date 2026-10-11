import 'dart:io';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

Future<void> main() async {
  final client = await VmClient.connect(Uri.parse(Platform.environment['LA_VM_URI']!));
  final tree = await client
      .callExtension(ToolkitExtensions.snapshot, args: const {})
      .timeout(const Duration(seconds: 25));
  for (final n in (tree['nodes']! as List<Object?>).whereType<Map<String, Object?>>()) {
    final label = '${n['label']}';
    if (label.contains('Exception') || label.contains('Directory')) {
      stdout.writeln(label);
    }
  }
  exit(0);
}
