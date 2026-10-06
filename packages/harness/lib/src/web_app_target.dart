import 'dart:io';

import 'package:universal_browser_cdp/universal_browser_cdp.dart';

import 'chrome_app_target.dart';
import 'flutter_web_cdp.dart';

/// Serves a built Flutter web bundle on loopback. A plain static server
/// with correct MIME types (a wrong type renders the HTML as TEXT —
/// measured) and an index.html fallback. The [WebBuildTarget] owns one;
/// hand-rolling this per project is where port/MIME flakiness came from.
final class StaticWebServer {
  StaticWebServer._(this._server, this.root);
  final HttpServer _server;
  final Directory root;

  /// The base URL the bundle is served under.
  Uri get base => Uri.parse('http://127.0.0.1:${_server.port}/');

  static const _mime = <String, String>{
    '.html': 'text/html',
    '.js': 'application/javascript',
    '.mjs': 'application/javascript',
    '.json': 'application/json',
    '.wasm': 'application/wasm',
    '.css': 'text/css',
    '.png': 'image/png',
    '.svg': 'image/svg+xml',
    '.ttf': 'font/ttf',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.map': 'application/json',
  };

  /// Binds [root] on [port] (0 = a free loopback port).
  static Future<StaticWebServer> start(Directory root, {int port = 0}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    server.listen((request) async {
      final path = request.uri.path == '/' ? '/index.html' : request.uri.path;
      var file = File('${root.path}$path');
      if (!file.existsSync()) file = File('${root.path}/index.html');
      final ext = file.path.contains('.')
          ? file.path.substring(file.path.lastIndexOf('.'))
          : '';
      request.response.headers.contentType =
          ContentType.parse(_mime[ext] ?? 'application/octet-stream');
      await request.response.addStream(file.openRead());
      await request.response.close();
    });
    return StaticWebServer._(server, root);
  }

  Future<void> stop() => _server.close(force: true);
}

/// The web leg of a scenario: build the Flutter web bundle, serve it,
/// attach Chrome over CDP, and hand the scenario a [CdpDriver] — the
/// AOT/web tier where the VM-service toolkit cannot exist (no VM
/// service in an AOT web build; JIT/debug apps keep the toolkit tier).
///
/// Build skipping: pass [build] false when `build/web` is already fresh
/// (the caller owns freshness — e.g. a source hash stamp).
final class WebBuildTarget {
  WebBuildTarget({
    required this.projectDir,
    this.buildCommand = const ['flutter', 'build', 'web', '--debug'],
    this.webDir = 'build/web',
    this.webPort = 0,
    this.chromeCdpPort = 0,
    this.headless = false,
    this.build = true,
  });

  /// The Flutter project directory.
  final String projectDir;

  /// The build command (argv). `--no-pub` is appended when
  /// [skipPubGet]… it is not: pass it inside the command when wanted.
  final List<String> buildCommand;

  /// The build output directory to serve, relative to [projectDir].
  final String webDir;

  /// Fixed web port; 0 picks a free one. A fixed port keeps evidence
  /// URLs stable across runs.
  final int webPort;

  /// Fixed Chrome CDP port; 0 picks a free one. Picking free is the
  /// DEFAULT for a reason: a fixed CDP port gets adopted as a borrowed
  /// session when a stale Chrome from a crashed run is still answering
  /// (measured) — a zombie browser with no page targets fails the
  /// attach.
  final int chromeCdpPort;

  /// Headless Chrome never runs requestAnimationFrame (no frame loop):
  /// the Flutter app freezes mid-boot and its semantics DOM stalls.
  /// Default headed — a real frame loop, like `flutter run -d chrome`.
  final bool headless;

  /// Whether to run [buildCommand] before serving.
  final bool build;

  /// Builds (when [build]), serves, launches Chrome, attaches, and
  /// returns the running app.
  Future<LaunchedWebApp> launch() async {
    if (build) {
      final result = await Process.run(
        buildCommand.first,
        [...buildCommand.sublist(1), '--project-directory', projectDir],
        runInShell: Platform.isWindows,
      );
      if (result.exitCode != 0) {
        throw ProcessException(
          buildCommand.first,
          buildCommand.sublist(1),
          'flutter web build failed (exit ${result.exitCode}):\n'
          '${result.stdout}\n${result.stderr}',
          result.exitCode,
        );
      }
    }
    final webRoot = Directory('$projectDir/$webDir');
    if (!webRoot.existsSync()) {
      throw StateError(
        '$webDir is missing — run with build: true or build it first',
      );
    }
    final server = await StaticWebServer.start(webRoot, port: webPort);
    final chromeTarget = ChromeAppTarget(
      port: chromeCdpPort != 0
          ? chromeCdpPort
          : await _freePort(),
      headless: headless,
      startUrl: server.base,
    );
    final chrome = await chromeTarget.launch();
    final session = await chrome.attach();
    return LaunchedWebApp._(server, chrome, session);
  }

  Future<int> _freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }
}

/// A running web app: the CDP page/driver plus the servers it came
/// from. [stop] tears down what this target owns (borrowed Chrome is
/// left running, per the borrowed-lease rule).
final class LaunchedWebApp {
  LaunchedWebApp._(this._server, this._chrome, this._session);

  final StaticWebServer _server;
  final LaunchedChrome _chrome;
  final CdpBrowserSession _session;

  /// The served bundle's base URL.
  Uri get url => _server.base;

  /// The attached page facade (navigation, evaluate, network log).
  CdpPage get page => _session.page;

  /// The observe/act/verify driver over [page].
  CdpDriver get driver => _session.driver;

  /// The Flutter-web driving techniques (locate-by-name, effect-verified
  /// clicks, caret typing, route pops) over [page].
  FlutterWebCdp get flutter => FlutterWebCdp(_session.page, _session.driver);

  /// Stops the servers and Chrome (unless borrowed). Idempotent.
  Future<void> stop() async {
    await _session.detach();
    await _chrome.stop();
    await _server.stop();
  }
}
