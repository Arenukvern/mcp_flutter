import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:path/path.dart' as p;
import 'package:universal_automation_interface/universal_automation_interface.dart';

/// Short Linux harness smoke: launch [native_layer_capture_fixture], tap
/// increment once, assert counter == 1. Used by `harness.tape` and CI GIF regen.
Future<void> main(List<String> args) async {
  final repoRoot = p.normalize(
    p.join(p.dirname(Platform.script.toFilePath()), '..', '..', '..', '..'),
  );
  final appDir = p.join(
    repoRoot,
    'showcase',
    'native_layer_capture_fixture',
  );
  final device = args.contains('--device')
      ? args[args.indexOf('--device') + 1]
      : (Platform.environment['HARNESS_GIF_DEVICE'] ?? 'linux');
  final extraArgs = <String>[
    if (device == 'chrome') ...const [
      '--web-port=9876',
      '--web-browser-flag=--headless=new',
      '--web-browser-flag=--disable-gpu',
    ],
  ];

  LaunchedApp? app;
  var passed = false;
  try {
    final scenario = Scenario('harness counter smoke', steps: [
      (
        'launch fixture',
        (context) async {
          app = await FlutterRunTarget(
            projectDir: appDir,
            device: device,
            extraArgs: extraArgs,
            name: 'harness-smoke',
          ).launch();
          context.bag['app'] = app;
          context.report.pass('vm ${app!.vmUri}');
          stdout.writeln('HARNESS_VM_URI=${app!.vmUri}');
        },
      ),
      (
        'tap increment',
        (context) async {
          final launched = context.take<LaunchedApp>('app');
          final driver = await attachDriver(launched);
          final before = await _counter(driver);
          await _tapIncrement(driver);
          await Future<void>.delayed(const Duration(milliseconds: 400));
          final after = await _counter(driver);
          if (after != before + 1) {
            return context.report.fail('counter $before -> $after (expected +1)');
          }
          context.report.pass('counter $before -> $after');
        },
      ),
    ]);
    passed = await scenario.run();
    scenario.report.printSummary();
  } finally {
    await app?.stop();
  }
  exit(passed ? 0 : 1);
}

Future<int> _counter(ToolkitDriver driver) async {
  for (final node in (await driver.snapshot()).nodes) {
    if (node.attributes['identifier'] == 'native_layer_counter_value') {
      final parsed = int.tryParse(node.value ?? node.name ?? '');
      if (parsed != null) return parsed;
    }
  }
  throw StateError('native_layer_counter_value not found');
}

Future<void> _tapIncrement(ToolkitDriver driver) async {
  for (final node in (await driver.snapshot()).nodes) {
    if (node.attributes['identifier'] == 'native_layer_increment_button') {
      final ref = node.attributes['ref'];
      if (ref is String) {
        await driver.perform(ClickAction(css: ref));
        return;
      }
    }
  }
  throw StateError('native_layer_increment_button ref not found');
}