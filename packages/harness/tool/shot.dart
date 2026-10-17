import 'dart:io';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

Future<void> main(List<String> args) async {
  final out = args.isNotEmpty ? args.first : '/tmp';
  final client = await VmClient.connect(Uri.parse(Platform.environment['LA_VM_URI']!));
  final driver = ToolkitDriver(client);
  final shot = await driver.screenshot().timeout(const Duration(seconds: 25));
  await File('$out/la-now.png').writeAsBytes(shot);
  stdout.writeln('$out/la-now.png');
  exit(0);
}
