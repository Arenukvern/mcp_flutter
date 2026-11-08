import 'dart:io';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

Future<void> main(List<String> args) async {
  final out = args.isNotEmpty ? args.first : '/tmp';
  final uriText =
      (args.length > 1 ? args[1] : null) ?? Platform.environment['LA_VM_URI'];
  if (uriText == null || uriText.isEmpty) {
    stderr.writeln(
      'usage: dart run shot.dart [outDir] [vmServiceUri]  '
      '(or set LA_VM_URI; the URI is printed by `flutter run`)',
    );
    exit(2);
  }
  final client = await VmClient.connect(Uri.parse(uriText));
  final driver = ToolkitDriver(client);
  final shot = await driver.screenshot().timeout(const Duration(seconds: 25));
  await File('$out/la-now.png').writeAsBytes(shot);
  stdout.writeln('$out/la-now.png');
  exit(0);
}
