import 'dart:convert';
import 'dart:io';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

Future<void> main() async {
  final client = await VmClient.connect(
    Uri.parse('http://127.0.0.1:58092/zhhsqmOHgUQ=/'),
  );
  final snap = await client.callExtension(ToolkitExtensions.snapshot);
  await File('/tmp/la-fresh-semantic.json').writeAsString(
    const JsonEncoder.withIndent(' ').convert(snap),
  );
  print('snapshot nodes: ${snap['nodes']?.length ?? 0}');
}
