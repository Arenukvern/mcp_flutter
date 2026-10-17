import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

/// Visual probe over a running, instrumented Flutter app: screenshot the
/// current surface, list declared surface actions, then optionally
/// navigate. Usage: dart run tool/visual_probe.dart [outDir] [route]
Future<void> main(final List<String> args) async {
  final out = args.isNotEmpty ? args.first : '/tmp';
  final vmUri = Platform.environment['LA_VM_URI'] ??
      'http://127.0.0.1:57684/${Platform.environment['LA_VM_TOKEN'] ?? ''}/';
  final client = await VmClient.connect(Uri.parse(vmUri));
  final driver = ToolkitDriver(client);
  try {
    final png = await driver.screenshot();
    final home = File('$out/la-current.png');
    await home.writeAsBytes(png);
    stdout.writeln('screenshot: ${home.path} (${png.length} bytes)');

    final actions = await driver.actions();
    stdout.writeln('surface actions (${actions.length}):');
    for (final action in actions) {
      stdout.writeln(
'  - ${action.name} — ${action.description}',
      );
    }

    if (args.length > 1) {
      await driver.perform(NavigateAction(Uri.parse(args[1])));
      final png2 = await driver.screenshot();
      final target = File('$out/la-navigated.png');
      await target.writeAsBytes(png2);
      stdout.writeln('navigated screenshot: ${target.path}');
    }
  } finally {
    await driver.close();
  }
}
