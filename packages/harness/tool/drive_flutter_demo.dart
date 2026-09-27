/// Instrumented-tier showcase: drives `showcase/flutter_demo` end to end
/// through the [ToolkitDriver] — the same observe/act/verify vocabulary
/// the CDP and OS-native drivers speak (ADR 0038) — and proves the
/// capture split by streaming PNG frames from the running app into a
/// `universal_screencast` pipeline.
///
///   dart run packages/harness/tool/drive_flutter_demo.dart
///   dart run packages/harness/tool/drive_flutter_demo.dart --device chrome
///
/// Steps: observe (semantic tree) → act (tap Increment ×3, type a name,
/// push the `/profile` named route) → verify (rendered text) → capture
/// (single-frame screenshots + a recorded frame stream under
/// `.showcase/`). The app bring-up is a first-owner `flutter run`
/// session; Ctrl-C or completion tears it down.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:path/path.dart' as p;
import 'package:universal_automation_interface/universal_automation_interface.dart';
import 'package:universal_capture_flutter/universal_capture_flutter.dart';
import 'package:universal_screencast/universal_screencast.dart';

final String repoRoot = p.normalize(
  p.join(p.dirname(Platform.script.toFilePath()), '..', '..', '..'),
);

final String outDir = p.join(repoRoot, '.showcase');

Future<void> main(final List<String> arguments) async {
  final device = arguments.contains('--device')
      ? arguments[arguments.indexOf('--device') + 1]
      : 'macos';
  Directory(outDir).createSync(recursive: true);
  final logFile = File(p.join(outDir, 'drive_flutter.log'));
  final logSink = logFile.openWrite(mode: FileMode.write);

  void log(final String message) {
    // ignore: avoid_print
    print('[drive_flutter] $message');
    logSink.writeln(message);
  }

  log('flutter run -d $device (showcase/flutter_demo); first build may '
      'take minutes — full tool output: ${p.relative(logFile.path, from: repoRoot)}');
  final app = FlutterRunTarget(
    projectDir: p.join(repoRoot, 'showcase', 'flutter_demo'),
    device: device,
    extraArgs: device == 'chrome' ? const ['--web-port=8792'] : const [],
    onLine: logSink.writeln,
    vmServiceTimeout: const Duration(minutes: 10),
  );

  final launched = await app.launch();
  final client = await launched.vm();
  final driver = ToolkitDriver(client);
  log('attached; toolkit isolate ${client.boundIsolateId}');

  try {
    // -- observe ------------------------------------------------------------
    final snapshot = await driver.snapshot();
    log('observed ${snapshot.nodes.length} semantic nodes (revision '
        '${snapshot.revision}):');
    _printTree(snapshot, log);

    // -- act ----------------------------------------------------------------
    for (var i = 0; i < 3; i++) {
      await driver.perform(const ClickAction(name: 'Increment'));
    }
    await driver.perform(const TypeAction('Ada', css: 'Name'));
    log('acted: tapped Increment ×3, typed "Ada" into Name');

    // -- verify -------------------------------------------------------------
    final counter = await _labelContaining(driver, 'Count: 3');
    if (counter == null) {
      throw StateError('verify failed: "Count: 3" not on screen');
    }
    log('verified: "$counter"');

    final mainPng = await driver.screenshot();
    await File(
      p.join(outDir, 'flutter_demo_main.png'),
    ).writeAsBytes(mainPng);
    log('captured single frame: .showcase/flutter_demo_main.png '
        '(${mainPng.length} bytes)');

    // -- continuous frames (capture split, ADR 0038) ------------------------
    final grab = await VmScreenshotGrabber.connect(launched.vmUri);
    final receipts = FileRecorderSink(directory: outDir, base: 'flutter_demo');
    final pipeline = await ScreencastPipeline.start(
      ScreencastComposition(
        source: ToolkitFrameSource(grab: grab.grab),
        sinks: [receipts],
      ),
    );
    final delivered = pipeline.events
        .where((event) => event is FrameDelivered)
        .cast<FrameDelivered>()
        .take(4);
    await driver.perform(const ClickAction(name: 'Increment'));
    final frames = await delivered.toList();
    await pipeline.stop();
    await grab.close();
    log('streamed ${frames.length} PNG frames through the screencast '
        'pipeline → .showcase/flutter_demo.frames.mjpeg (+ .meta.jsonl)');

    // -- named-route navigation ---------------------------------------------
    // NavigateAction carries a route, no arguments — the app renders its
    // "friend" fallback name; the assertion is that the named route landed.
    await driver.perform(NavigateAction(Uri.parse('/profile')));
    final greeting = await _labelContaining(driver, 'Hello,');
    if (greeting == null) {
      throw StateError('verify failed: "/profile" did not render greeting');
    }
    final profilePng = await driver.screenshot();
    await File(p.join(outDir, 'flutter_demo_profile.png')).writeAsBytes(
      profilePng,
    );
    log('verified: "$greeting" (named route push) + '
        '.showcase/flutter_demo_profile.png');

    log('OK — one driver contract, one instrumented Flutter app.');
  } finally {
    await driver.close();
    final code = await launched.stop();
    await logSink.flush();
    await logSink.close();
    if (code != 0) {
      log('flutter run exited $code');
    }
  }
}

Future<String?> _labelContaining(
  final ToolkitDriver driver,
  final String needle,
) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    for (final node in (await driver.snapshot()).nodes) {
      if ((node.name ?? '').contains(needle)) return node.name;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  return null;
}

void _printTree(final Snapshot snapshot, final void Function(String) log) {
  String describe(final AxNode node, final int depth) {
    final indent = '  ' * depth;
    final name = node.name == null ? '' : ' "${node.name}"';
    final bounds = node.bounds;
    final at = bounds == null
        ? ''
        : ' @${bounds.left.round()},${bounds.top.round()}';
    final ref = node.attributes['ref'];
    return '$indent${node.role}$name$at [ref=$ref]';
  }

  void walk(final AxNode node, final int depth) {
    log(describe(node, depth));
    for (final child in node.children) {
      walk(child, depth + 1);
    }
  }

  for (final root in snapshot.roots) {
    walk(root, 0);
  }
}
