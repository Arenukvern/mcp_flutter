import 'dart:io';

import 'package:oka_harness/oka_harness.dart';
import 'package:universal_automation_interface/universal_automation_interface.dart';

/// Drive an Android app end-to-end through `oka dev` + the toolkit
/// extensions (ADR-0026). Run from a device-connected project root:
///
///   dart run example/emulator_smoke.dart /path/to/flutter_app
///
/// The app must embed `mcp_toolkit` (`MCPToolkitBinding` in `main`) so the
/// snapshot/tap extensions are registered.
Future<void> main(List<String> args) async {
  final projectDir = args.first;
  final app = await AndroidAppTarget(
    projectDir: projectDir,
    // deviceId: 'emulator-5554', // pin on multi-device hosts
    dartDefines: {'MY_APP_FLOW': 'smoke'},
  ).launch();

  var passed = false;
  try {
    final driver = await driverForLiveSession(projectDir);

    final snap = await driver.snapshot();
    final start = snap.nodes
        .where(
          (node) =>
              (node.name ?? '').toLowerCase().contains('start'),
        )
        .toList();
    if (start.isEmpty) {
      stdout.writeln('FAIL: start button not found in semantic snapshot');
      for (final node in snap.nodes) {
        stdout.writeln('  node: ${node.role} ${node.name ?? ''}');
      }
    } else {
      await driver.perform(const ClickAction(name: 'start'));
      String? confirmation;
      for (var attempt = 0; attempt < 10 && confirmation == null; attempt++) {
        final after = await driver.snapshot();
        for (final n in after.nodes) {
          final value = n.value ?? '';
          if (value.startsWith('SMOKE-')) confirmation = value;
        }
        if (confirmation == null) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      passed = confirmation != null;
      stdout.writeln(
        passed
            ? 'PASS: flow confirmed via $confirmation'
            : 'FAIL: no SMOKE-* value in snapshot',
      );
    }
  } finally {
    await app.stop();
  }
  exit(passed ? 0 : 1);
}
