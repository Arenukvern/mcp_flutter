import 'dart:io';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

Future<void> main(List<String> args) async {
  final dir = args.first;
  final dist = args.length > 1 ? args[1] : '4000';
  final client = await VmClient.connect(Uri.parse(Platform.environment['LA_VM_URI']!));
  await client
      .callExtension(ToolkitExtensions.scroll,
          args: {'direction': dir, 'distance': int.parse(dist)})
      .timeout(const Duration(seconds: 25));
  await Future<void>.delayed(const Duration(milliseconds: 600));
  stdout.writeln('scrolled $dir $dist');
  exit(0);
}
