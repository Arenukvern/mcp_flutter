import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:path/path.dart' as p;

/// Two-instance desktop pair E2E (the shape proven in the vosges project).
///
/// Instance A hosts; instance B launches in a "controller" role via an env
/// var your app reads at startup. B copies a pairing code (read here from
/// the code file the app writes, but `driver.findValue` can read it straight
/// off a selectable-text node), A accepts it, B connects, and A's log
/// proves gesture dispatch.
///
/// Adapt the marked lines to your app; the harness plumbing is generic.
///
/// Usage:
///   dart run example/desktop_pair.dart [--skip-build]
Future<void> main(final List<String> args) async {
  final build = !args.contains('--skip-build');
  final appDir = 'flutter_test_app'; // adapt: your Flutter desktop project
  final binary = p.join(
    appDir,
    'build',
    'macos',
    'Build',
    'Products',
    'Debug',
    'Your App.app', // adapt: build/.../YourApp.app/Contents/MacOS/YourApp
    'Contents',
    'MacOS',
    'Your App',
  );

  LaunchedApp? host;
  LaunchedApp? controller;
  var passed = false;
  try {
    final scenario = Scenario('desktop pair E2E', steps: [
      (
        'launch host A',
        (final context) async {
          final launched = await MacosAppTarget(
            projectDir: appDir,
            binaryPath: binary,
            environment: {'MY_APP_ROLE': 'host'},
          ).launch(build: build);
          host = launched;
          context.bag['host'] = launched;
          await launched.stdout.waitFor('app started');
          context.report.pass('host at ${launched.vmUri}');
        },
      ),
      (
        'launch controller B',
        (final context) async {
          final launched = await MacosAppTarget(
            projectDir: appDir,
            binaryPath: binary,
            environment: {'MY_APP_ROLE': 'controller'},
          ).launch(build: build);
          controller = launched;
          context.bag['controller'] = launched;
          await launched.stdout.waitFor('app started');
          context.report.pass('controller at ${launched.vmUri}');
        },
      ),
      (
        'B: drive the UI through A flow',
        (final context) async {
          final hostApp = context.take<LaunchedApp>('host');
          final ctrlApp = context.take<LaunchedApp>('controller');
          final hostDriver = await attachDriver(hostApp);
          final ctrlDriver = await attachDriver(ctrlApp);

          // Tap connect (by label) until A reports B joined — a tap lands
          // before the next frame paints, so the peer wait must retry.
          var joined = false;
          for (var attempt = 0; attempt < 10 && !joined; attempt++) {
            await ctrlDriver.perform(
              const ClickAction(name: 'connect'),
            );
            joined = hostApp.stdout.firstMatch('peer joined') != null;
            if (!joined) {
              await Future<void>.delayed(const Duration(milliseconds: 500));
            }
          }
          if (!joined) {
            context.report.fail('A never saw B join');
            return;
          }

          // Read app-rendered data off a node value in the snapshot.
          String? code;
          for (final node in (await ctrlDriver.snapshot()).nodes) {
            final value = node.value;
            if (value != null && value.startsWith('MYAPP-')) {
              code = value;
              break;
            }
          }
          if (code == null) {
            context.report.fail('no code value in snapshot');
            return;
          }
          await hostDriver.perform(const ClickAction(name: 'accept'));
          context.report.pass('pairing code exchanged (${code.length} chars)');
        },
      ),
    ]);

    passed = await scenario.run();
    scenario.report.printSummary();
    if (!passed) {
      stdout.writeln('---- host tail ----');
      for (final line in host?.stdout.tail(25) ?? const <String>[]) {
        stdout.writeln(line);
      }
    }
  } finally {
    await controller?.stop();
    await host?.stop();
  }
  exit(passed ? 0 : 1);
}
