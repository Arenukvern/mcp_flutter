/// macOS-tier showcase: drives a REAL desktop application through the
/// family's [MacosDriver] — the same observe/act/verify loop
/// `drive_web.dart` speaks over CDP and the instrumented Flutter driver
/// speaks over the VM service — plus the app-management surface that
/// makes it the macOS rung: discover what is running, bring the target
/// forward (activate), observe a BACKGROUND app by pid, and capture.
///
///   dart run showcase/drivers/bin/drive_macos.dart
///   dart run showcase/drivers/bin/drive_macos.dart --bundle com.apple.Safari
///   dart run showcase/drivers/bin/drive_macos.dart --pid 1234 --click Settings
///
/// Target selection (borrowed-lease rule: an already-running app is
/// activated, never relaunched; the default target is the FRONTMOST
/// app). Requires the process to hold the Accessibility TCC grant
/// (tree) and Screen Recording (screenshot); artifacts land under
/// `.showcase/`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:universal_automation_interface/universal_automation_interface.dart';
import 'package:universal_driver_macos/universal_driver_macos.dart';

final String repoRoot = p.normalize(
  p.join(p.dirname(Platform.script.toFilePath()), '..', '..', '..'),
);

final String outDir = p.join(repoRoot, '.showcase');

/// Resolves the target app: explicit --pid / --bundle, else frontmost.
Future<MacosApp> resolveTarget(
  MacosDriver driver,
  Map<String, String> flags,
  void Function(String) log,
) async {
  final pidFlag = flags['pid'];
  final bundleFlag = flags['bundle'];
  if (pidFlag != null) {
    final pid = int.tryParse(pidFlag);
    if (pid == null) {
      throw ArgumentError('--pid must be an integer, got "$pidFlag"');
    }
    final match = await driver.runningApps().then(
      (apps) => apps.where((app) => app.pid == pid).toList(),
    );
    if (match.isEmpty) {
      throw StateError('no running regular app with pid $pid');
    }
    return match.single;
  }
  if (bundleFlag != null) {
    // Launch-or-activate: a running app is adopted (borrowed lease), a
    // stopped one is launched — both end with the app in front.
    final pid = await driver.launch(bundleFlag);
    final match = await driver.runningApps().then(
      (apps) => apps.where((app) => app.pid == pid).toList(),
    );
    if (match.isNotEmpty) return match.single;
    return MacosApp(pid: pid, name: bundleFlag, active: true, hidden: false);
  }
  final front = await driver.frontmost();
  log('no --pid/--bundle given; targeting the frontmost app');
  return front;
}

Future<void> main(final List<String> arguments) async {
  Directory(outDir).createSync(recursive: true);
  final flags = <String, String>{
    for (var i = 0; i < arguments.length - 1; i++)
      if (arguments[i].startsWith('--'))
        arguments[i].substring(2): arguments[i + 1],
  };
  final clickTarget = flags['click'];

  void log(final String message) {
    // ignore: avoid_print
    print('[drive_macos] $message');
  }

  final driver = MacosDriver();
  if (!driver.axTrusted) {
    log('Accessibility TCC missing — prompting once, then rerun');
    driver.requestTrust();
    exitCode = 3;
    return;
  }

  try {
    // -- observe (discovery) ------------------------------------------
    final apps = await driver.runningApps();
    log('${apps.length} running regular apps');
    for (final app in apps.take(6)) {
      log('  pid=${app.pid} ${app.name} '
          '${app.active ? '(frontmost)' : ''}');
    }

    // -- target + activate --------------------------------------------
    final target = await resolveTarget(driver, flags, log);
    log('target: ${target.name} (pid ${target.pid})');
    if (!target.active) {
      await driver.activate(target.pid);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      log('activated');
    }

    // -- observe (the target's tree) ----------------------------------
    final snapshot = await driver.snapshot();
    log('snapshot: ${snapshot.nodes.length} nodes, '
        'root=${snapshot.roots.first.role} "${snapshot.roots.first.name}"');
    final snapshotFile = File(
      p.join(outDir, 'macos-${target.pid}-snapshot.json'),
    );
    await snapshotFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
    );

    // -- observe (a BACKGROUND app by pid — the focused-only driver
    //    could never do this) -----------------------------------------
    final background = apps
        .where((app) => app.pid != target.pid && app.pid > 0)
        .toList();
    if (background.isNotEmpty) {
      final other = background.first;
      final backgroundSnapshot = await driver.snapshotOfApp(other.pid);
      log('background read: ${other.name} → '
          '${backgroundSnapshot.nodes.length} nodes');
    }

    // -- act ------------------------------------------------------------
    if (clickTarget != null) {
      await driver.perform(ClickAction(name: clickTarget));
      log('clicked "$clickTarget"');
    }

    // -- verify + capture ----------------------------------------------
    final after = await driver.snapshot();
    log('verify: revision ${snapshot.revision} → ${after.revision}');
    final shot = await driver.screenshot();
    final shotFile = File(p.join(outDir, 'macos-${target.pid}.png'));
    await shotFile.writeAsBytes(shot);
    log('screenshot → ${shotFile.path} (${shot.length} bytes)');
    log('done');
  } finally {
    await driver.close();
  }
}
