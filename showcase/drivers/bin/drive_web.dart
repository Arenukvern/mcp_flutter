/// Browser-tier showcase: serves `showcase/web_demo`, launches Chrome
/// through the harness's [ChromeAppTarget], and drives it with the
/// family's [CdpDriver] — the same observe/act/verify loop the
/// instrumented [ToolkitDriver] speaks, over CDP instead of the VM
/// service — then streams the page's own screencast into the same
/// `universal_screencast` pipeline.
///
///   dart run showcase/drivers/bin/drive_web.dart
///   dart run showcase/drivers/bin/drive_web.dart --visible
///
/// Steps: serve (loopback static server) → observe (CDP accessibility
/// tree) → act (click `#increment` ×3, type into `#name`, open the
/// profile section) → verify (rendered text via the semantic tree) →
/// capture (CDP screenshot + a recorded screencast under `.showcase/`).
/// The Chrome session is owned (isolated profile) and torn down at the
/// end; a Chrome already answering on the port is adopted as a borrowed
/// lease and left running.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:path/path.dart' as p;
import 'package:universal_automation_interface/universal_automation_interface.dart';
import 'package:universal_browser_cdp/universal_browser_cdp.dart';
import 'package:universal_screencast/universal_screencast.dart';

final String repoRoot = p.normalize(
  p.join(p.dirname(Platform.script.toFilePath()), '..', '..', '..'),
);

final String outDir = p.join(repoRoot, '.showcase');

const int servePort = 8791;
const int chromePort = 9223;

Future<void> main(final List<String> arguments) async {
  final visible = arguments.contains('--visible');
  Directory(outDir).createSync(recursive: true);

  void log(final String message) {
    // ignore: avoid_print
    print('[drive_web] $message');
  }

  // -- serve ---------------------------------------------------------------
  // Borrowed-lease rule for the demo server too: something already
  // answering on the port is reused (reported, never killed) — a leaked
  // serve process from an earlier failed run serves exactly the same
  // page, so reruns don't fight it. Otherwise serve IN-PROCESS: same
  // 20 lines as showcase/web_demo/serve.dart (kept for humans), minus
  // an entire child-process failure class.
  HttpServer? server;
  if (await _portOpen(servePort)) {
    log('reusing server already answering on port $servePort');
  } else {
    final page = File(
      p.join(repoRoot, 'showcase', 'web_demo', 'index.html'),
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, servePort);
    unawaited(
      server.forEach((request) async {
        if (!page.existsSync()) {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('index.html missing under showcase/web_demo/');
        } else {
          request.response.headers.contentType = ContentType.html;
          await request.response.addStream(page.openRead());
        }
        await request.response.close();
      }),
    );
    log('serving showcase/web_demo at http://127.0.0.1:$servePort/ '
        '(in-process)');
  }

  // -- bring-up --------------------------------------------------------------
  final chrome = ChromeAppTarget(
    port: chromePort,
    headless: !visible,
    startUrl: Uri.parse('http://127.0.0.1:$servePort/'),
  );
  final launched = await chrome.launch();
  final session = await launched.attach();
  final driver = session.driver;
  log('attached Chrome on CDP port $chromePort '
      '(${launched.borrowed ? 'borrowed session — will not be killed' : 'owned session'})');

  try {
    // -- observe -------------------------------------------------------------
    final snapshot = await driver.snapshot();
    log('observed ${snapshot.nodes.length} accessibility nodes:');
    for (final node in snapshot.nodes.take(12)) {
      log('  ${node.role}${node.name == null ? '' : ' "${node.name}"'}');
    }

    // -- act -----------------------------------------------------------------
    for (var i = 0; i < 3; i++) {
      await driver.perform(const ClickAction(css: '#increment'));
    }
    await driver.perform(const TypeAction('Ada', css: '#name'));
    await driver.perform(const ClickAction(css: '#open-profile'));
    log('acted: clicked #increment ×3, typed into #name, opened #profile');

    // -- verify --------------------------------------------------------------
    final greeting = await _textPresent(driver, 'Hello, Ada!');
    if (!greeting) {
      throw StateError('verify failed: "Hello, Ada!" not in the a11y tree');
    }
    log('verified: "Hello, Ada!" rendered and exposed to the tree');

    final png = await driver.screenshot();
    await File(p.join(outDir, 'web_demo.png')).writeAsBytes(png);
    log('captured single frame: .showcase/web_demo.png (${png.length} bytes)');

    // -- continuous frames ----------------------------------------------------
    // Real Chrome pushes a screencast frame on start and then one per
    // paint (never on a silent page), so drive paints while collecting;
    // cap the wait so a quiet page ends the stage honestly.
    final receipts = FileRecorderSink(directory: outDir, base: 'web_demo');
    final pipeline = await ScreencastPipeline.start(
      ScreencastComposition(
        source: CdpScreencastFrameSource(session.page.connection),
        sinks: [receipts],
      ),
    );
    final frames = <FrameDelivered>[];
    Future<void> collect() async {
      await for (final event in pipeline.events) {
        if (event is FrameDelivered) frames.add(event);
        if (frames.length >= 3) return;
      }
    }

    final collecting = collect();
    await driver.perform(const ClickAction(css: '#back'));
    await Future<void>.delayed(const Duration(seconds: 1));
    await driver.perform(const ClickAction(css: '#open-profile'));
    await collecting.timeout(
      const Duration(seconds: 20),
      onTimeout: () {},
    );
    await pipeline.stop();
    if (frames.isEmpty) {
      throw StateError('no screencast frames delivered');
    }
    log('streamed ${frames.length} JPEG frames through the screencast '
        'pipeline → .showcase/web_demo.frames.mjpeg (+ .meta.jsonl)');

    log('OK — one driver contract, one browser page.');
  } finally {
    // Borrowed leases: release only OUR websocket — `driver.close()` would
    // close the page target too, wiping a tab from someone else's browser
    // (learned the hard way: the adopted Chrome kept running with zero
    // targets). Owned sessions tear down fully.
    if (launched.borrowed) {
      await session.page.connection.close();
    } else {
      await driver.close();
      await launched.stop();
    }
    await server?.close(force: true);
  }
}

Future<bool> _portOpen(final int port) async {
  try {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      port,
      timeout: const Duration(milliseconds: 500),
    );
    await socket.close();
    return true;
  } on SocketException {
    return false;
  }
}


Future<bool> _textPresent(final CdpDriver driver, final String needle) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    for (final node in (await driver.snapshot()).nodes) {
      if ((node.name ?? '').contains(needle) ||
          (node.value ?? '').contains(needle)) {
        return true;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  return false;
}
