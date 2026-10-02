import 'dart:convert';
import 'dart:io';

import 'package:universal_browser_cdp/universal_browser_cdp.dart';

import 'log_tap.dart';

/// Bring-up for a Chrome/Chromium target in web scenarios.
///
/// Mirrors [BinaryAppTarget]'s philosophy one surface up: **own the
/// process** (fixed debug port, isolated user-data-dir, explicit
/// lifecycle), publish the endpoint, and let the protocol client
/// (`universal_browser_cdp`) attach to it. Chrome never speaks the Dart
/// VM service, so this target produces a [LaunchedChrome] — not a
/// [LaunchedApp]; the observe/act/verify loop runs through
/// [LaunchedChrome.driver] over CDP instead of toolkit extensions.
///
/// The compile step is deliberately absent: serve the web build (or any
/// URL) yourself and point [ChromeAppTarget.startUrl] at it. This type
/// does not implement [AppTarget] on purpose — scenarios that mix app
/// and browser targets compose the two handles explicitly.
final class ChromeAppTarget {
  ChromeAppTarget({
    required this.port,
    this.binary,
    this.headless = true,
    this.startUrl,
    this.windowWidth = 1365,
    this.windowHeight = 768,
    this.userDataDir,
    this.extraArgs = const [
      // An occluded/background window gets its rAF throttled to a stop —
      // the Flutter app freezes mid-render and its semantics DOM never
      // updates (measured driving a Flutter web gate beside other
      // windows). The same three flags `flutter run -d chrome` passes.
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
    ],
  });

  /// Fixed CDP debug port. A fixed port keeps the reuse story simple:
  /// a port already answering CDP is adopted as a borrowed session and
  /// never killed (oka's borrowed-lease rule).
  final int port;

  /// Chrome executable; defaults to the macOS install path, then `PATH`.
  final String? binary;

  final bool headless;
  final Uri? startUrl;
  final int windowWidth;
  final int windowHeight;

  /// Isolated profile directory; a temp dir when omitted.
  final String? userDataDir;

  /// Extra Chromium switches prepended to the launch args; defaults to
  /// the background-throttling disables every automation target needs.
  final List<String> extraArgs;

  Directory? _ownedProfile;

  /// Polls [CdpDiscovery.version] until the endpoint answers or [deadline]
  /// passes — Chrome binds its DevTools socket only after boot, so the
  /// first probes legitimately see connection-refused.
  Future<CdpVersionInfo> _waitForCdp(final Uri httpBase, final int port) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (true) {
      final version = await CdpDiscovery.version(
        httpBase,
        timeout: const Duration(seconds: 2),
      );
      if (version != null) return version;
      if (DateTime.now().isAfter(deadline)) {
        throw EndpointUnreachableException(
          'Chrome answered no CDP probe on port $port within 30s',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<LaunchedChrome> launch({final bool build = false}) async {
    if (build) {
      throw ArgumentError(
        'ChromeAppTarget owns no build step; serve the web build '
        'yourself and pass its URL as startUrl',
      );
    }
    final httpBase = Uri.parse('http://127.0.0.1:$port');
    final existing = await CdpDiscovery.version(httpBase);
    if (existing != null) {
      // Borrowed session: report, never stop.
      return LaunchedChrome.borrowed(
        httpBase: httpBase,
        version: existing,
      );
    }

    final profilePath = userDataDir ?? _makeOwnedProfile().path;
    final executable = binary ?? _defaultBinary();
    final process = await Process.start(executable, [
      '--remote-debugging-port=$port',
      '--user-data-dir=$profilePath',
      '--no-first-run',
      '--no-default-browser-check',
      ...extraArgs,
      // Headless renders compute their accessibility tree lazily and
      // `Accessibility.enable` alone does not flip the renderer's AX
      // mode — without this, getFullAXTree answers with the root node
      // only (the same default Puppeteer uses for headless).
      '--force-renderer-accessibility',
      if (headless) '--headless=new',
      '--window-size=$windowWidth,$windowHeight',
      if (startUrl != null) startUrl!.toString(),
    ]);
    final tap = LogTap();
    const decoder = Utf8Decoder(allowMalformed: true);
    process.stdout.transform(decoder).transform(const LineSplitter()).listen(
          tap.add,
        );
    process.stderr.transform(decoder).transform(const LineSplitter()).listen(
          tap.add,
        );

    // Poll until the deadline: requireAlive probes exactly once, and on a
    // cold start that single probe loses the race against Chrome's boot
    // (~1s+ to bind the DevTools socket) with an instant ECONNREFUSED.
    // Retry every 250ms for up to 30s — fresh-profile headless boots on
    // slow machines are the target audience of this target.
    final version = await _waitForCdp(httpBase, port);
    return LaunchedChrome.owned(
      process: process,
      stdout: tap,
      httpBase: httpBase,
      version: version,
      ownedProfile: userDataDir == null ? _ownedProfile : null,
      onStop: _ownedProfile == null ? null : _deleteOwnedProfile,
    );
  }

  Directory _makeOwnedProfile() {
    final dir = Directory.systemTemp.createTempSync('chrome-harness-');
    _ownedProfile = dir;
    return dir;
  }

  Future<void> _deleteOwnedProfile() async {
    final dir = _ownedProfile;
    if (dir != null && dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup; a locked profile dir is harmless.
      }
    }
  }

  String _defaultBinary() {
    const macPath =
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
    if (Platform.isMacOS && File(macPath).existsSync()) return macPath;
    return Platform.isWindows ? 'chrome.exe' : 'google-chrome';
  }
}

/// A running (or borrowed) Chrome with its CDP endpoint.
final class LaunchedChrome {
  LaunchedChrome._({
    required this.httpBase,
    required this.version,
    this.process,
    this.stdout,
    this.ownedProfile,
    this.onStop,
  });

  /// We own the process and stop it on [stop].
  factory LaunchedChrome.owned({
    required Process process,
    required LogTap stdout,
    required Uri httpBase,
    required CdpVersionInfo version,
    Directory? ownedProfile,
    Future<void> Function()? onStop,
  }) =>
      LaunchedChrome._(
        httpBase: httpBase,
        version: version,
        process: process,
        stdout: stdout,
        ownedProfile: ownedProfile,
        onStop: onStop,
      );

  /// Someone else's session answering on our port: report, never stop.
  factory LaunchedChrome.borrowed({
    required Uri httpBase,
    required CdpVersionInfo version,
  }) =>
      LaunchedChrome._(httpBase: httpBase, version: version);

  final Uri httpBase;
  final CdpVersionInfo version;
  final Process? process;
  final LogTap? stdout;
  final Directory? ownedProfile;
  final Future<void> Function()? onStop;

  CdpBrowserSession? _session;

  /// True when this session was adopted, not launched: stop is a no-op.
  bool get borrowed => process == null;

  /// Attaches the protocol client (idempotent).
  Future<CdpBrowserSession> attach() async =>
      _session ??= await CdpBrowserSession.attach(httpBase);

  /// A driver over the first page target.
  Future<CdpDriver> driver() async => (await attach()).driver;

  /// Stops what we own; borrowed sessions are left untouched.
  Future<int> stop() async {
    final session = _session;
    if (session != null) await session.close();
    final process = this.process;
    if (process == null) return 0;
    await stdout?.close();
    process.kill(ProcessSignal.sigterm);
    final code = await process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return process.exitCode;
      },
    );
    await onStop?.call().catchError((final _) {});
    return code;
  }
}
