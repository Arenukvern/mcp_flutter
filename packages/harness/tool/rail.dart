import 'dart:io';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

Future<void> main(final List<String> args) async {
  final client = await VmClient.connect(Uri.parse(Platform.environment['LA_VM_URI']!));
  Future<Map<String, dynamic>> ext(final String name,
          {final Map<String, Object?> args = const {}}) =>
      client.callExtension(name, args: args).timeout(const Duration(seconds: 25));
  final tree = await ext(ToolkitExtensions.snapshot);
  final nodes = (tree['nodes']! as List<Object?>)
      .whereType<Map<String, Object?>>()
      .toList();
  for (final n in nodes) {
    if (n['type'] == 'button') {
      final c = n['center'] as Map<String, Object?>?;
      stdout.writeln(
          '${n['ref']} y=${c?['y']} x=${c?['x']} vis=${n['visibleInViewport']} label=${n['label'].toString().substring(0, n['label'].toString().length.clamp(0, 40))}');
    }
  }
  exit(0);
}
