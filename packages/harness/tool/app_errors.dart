import 'dart:convert';
import 'dart:io';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

Future<void> main() async {
  final client = await VmClient.connect(Uri.parse(Platform.environment['LA_VM_URI']!));
  final res = await client
      .callExtension('ext.mcp.toolkit.app_errors', args: const {})
      .timeout(const Duration(seconds: 25));
  stdout.writeln(const JsonEncoder.withIndent(' ').convert(res));
  exit(0);
}
