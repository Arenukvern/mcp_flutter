@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:oka_harness/oka_harness.dart';
import 'package:test/test.dart';

import '../support/linux_bounded_flutter_run.dart';
import '../support/native_layer_evidence.dart';

void main() {
  final runAndroid =
      Platform.environment['RUN_NATIVE_FLUTTER_LAYER_ANDROID'] == '1';
  final runLinux =
      Platform.environment['RUN_NATIVE_FLUTTER_LAYER_LINUX'] == '1';

  group('native flutter_layer capture (SDK owners)', () {
    final repoRoot = harnessRepoRoot();
    final appDir = nativeCaptureFixtureApp(repoRoot);
    final artifactDir = nativeCaptureArtifactDir();

    test(
      'workspace resolves in-tree flutter_mcp_harness',
      () async {
        final uri = await Isolate.resolvePackageUri(
          Uri.parse('package:flutter_mcp_harness/flutter_mcp_harness.dart'),
        );
        expect(uri, isNotNull);
        expect(uri!.path, contains('packages/harness'));
      },
      skip: !(runAndroid || runLinux)
          ? 'native env only'
          : false,
    );

    tearDownAll(() async {
      if (runAndroid || runLinux) {
        await writeJsonArtifact(
          artifactDir,
          'artifact_dir.json',
          {'path': artifactDir.path},
        );
      }
    });

    test(
      'Android: oka dev owns lifecycle; ToolkitDriver view_screenshots + CLI',
      () => _runNativeCapture(
        platform: 'android',
        artifactDir: artifactDir,
        appDir: appDir,
        launch: (combinedTap) async {
          final deviceId = Platform.environment['ANDROID_SERIAL'];
          if (deviceId == null || deviceId.isEmpty) {
            throw StateError('ANDROID_SERIAL is required for Android native proof');
          }
          final logcat = await AndroidEngineLogcatSession.start(
            deviceId: deviceId,
            sink: combinedTap,
          );
          final staleOkaDebug = Directory(
            '${appDir.path}/.oka_cache/build/debug',
          );
          if (staleOkaDebug.existsSync()) {
            staleOkaDebug.deleteSync(recursive: true);
          }
          final harnessDir = Directory.current.path.endsWith('harness')
              ? Directory.current
              : Directory('${Directory.current.path}/packages/harness');
          final target = AndroidAppTarget(
            projectDir: appDir.path,
            deviceId: deviceId,
            logcat: false,
            okaBin: '${harnessDir.path}/test/support/oka_dev_android.sh',
          );
          // oka dev android requires a session-manifest APK from `oka build`.
          final app = await target.launch(build: true);
          return _OwnedSession(
            app: app,
            logTap: combinedTap,
            appTap: app.stdout,
            logcat: logcat,
          );
        },
      ),
      tags: ['native-android'],
      skip: runAndroid
          ? false
          : 'Set RUN_NATIVE_FLUTTER_LAYER_ANDROID=1 (and oka + emulator)',
      timeout: const Timeout(Duration(minutes: 35)),
    );

    test(
      'Linux: runBounded flutter --machine owns lifecycle; driver + CLI',
      () => _runNativeCapture(
        platform: 'linux',
        artifactDir: artifactDir,
        appDir: appDir,
        launch: (tap) async {
          final linuxBinary = File(
            '${appDir.path}/build/linux/x64/debug/bundle/native_layer_capture_fixture',
          );
          final extraArgs = <String>['-v'];
          if (linuxBinary.existsSync()) {
            extraArgs.addAll([
              '--no-build',
              '--use-application-binary=${linuxBinary.path}',
            ]);
          }
          final app = await LinuxBoundedFlutterRunTarget(
            projectDir: appDir.path,
            extraArgs: extraArgs,
          ).launch();
          for (final line in app.stdout.lines) {
            tap.add(line);
          }
          return _OwnedSession(app: app, logTap: tap, appTap: app.stdout);
        },
      ),
      tags: ['native-linux'],
      skip: runLinux ? false : 'Set RUN_NATIVE_FLUTTER_LAYER_LINUX=1',
      timeout: const Timeout(Duration(minutes: 25)),
    );
  });
}

final class _OwnedSession {
  _OwnedSession({
    required this.app,
    required this.logTap,
    required this.appTap,
    this.logcat,
  });
  final LaunchedApp app;
  final LogTap logTap;
  final LogTap appTap;
  final AndroidEngineLogcatSession? logcat;
  var stopped = false;

  List<String> get combinedLogLines => [...logTap.lines, ...appTap.lines];
}

Future<void> _runNativeCapture({
  required String platform,
  required Directory artifactDir,
  required Directory appDir,
  required Future<_OwnedSession> Function(LogTap combinedTap) launch,
}) async {
  final repoRoot = harnessRepoRoot();
  final combinedTap = LogTap();
  final pubGet = await Process.run(
    'flutter',
    ['pub', 'get'],
    workingDirectory: appDir.path,
  );
  expect(pubGet.exitCode, 0, reason: '${pubGet.stderr}\n${pubGet.stdout}');

  _OwnedSession? session;
  ToolkitDriver? driver;

  try {
    session = await launch(combinedTap);
    final app = session.app;
    await vmHandshake(app.vmUri);
    driver = await attachDriver(app);

    final counterBefore = await counterFromDriver(driver);
    expect(counterBefore, 0);

    final before = await writePng(
      artifactDir,
      '${platform}_before_increment.png',
      await driver.screenshot(),
    );

    await tapIncrementButton(driver);
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    final counterAfter = await counterFromDriver(driver);
    final after = await writePng(
      artifactDir,
      '${platform}_after_increment.png',
      await driver.screenshot(),
    );

    final pixelProof = analyzeCapturePair(
      before: before,
      after: after,
      counterBefore: counterBefore,
      counterAfter: counterAfter,
    );
    await writeJsonArtifact(artifactDir, '${platform}_pixel_proof.json', {
      ...pixelProof,
      'captureBackend': captureBackendFlutterLayerVm,
      'captureImplementation': captureImplementationAppLayerTree,
      'observer': 'ToolkitDriver.view_screenshots.compress_false',
    });
    expect(pixelProof['verdict'], 'pass', reason: '$pixelProof');

    final cli = await runToolkitCliGetScreenshots(
      repoRoot: repoRoot,
      vmServiceUri: app.vmUri,
    );
    await writeJsonArtifact(
      artifactDir,
      '${platform}_cli_get_screenshots.json',
      cli,
    );
    expect(cli['ok'], isTrue, reason: '$cli');
    expect(cli['captureMode'], 'flutter_layer');
    expect(cli['captureBackend'], captureBackendFlutterLayerVm);
    expect(cli['captureImplementation'], captureImplementationAppLayerTree);
    final cliPng = cliPrimaryPngBytes(cli);
    expect(cliPng, isNotNull);
    if (cliPng != null) {
      await writePng(artifactDir, '${platform}_cli_compressed.png', cliPng);
    }
    final cliProof = analyzeCliCaptureProof(
      driverUncompressed: after,
      cliResult: cli,
    );
    await writeJsonArtifact(artifactDir, '${platform}_cli_capture_proof.json', cliProof);
    expect(cliProof['verdict'], 'pass', reason: '$cliProof');

    final renderer = rendererVerdictFromLogs(
      session.combinedLogLines,
      platform: platform,
    );
    await writeJsonArtifact(
      artifactDir,
      '${platform}_renderer_verdict.json',
      renderer,
    );
    expect(renderer['rendererAccepted'], isTrue, reason: '$renderer');

    await driver.close();
    driver = null;

    final exitCode = await app.stop();
    session.stopped = true;
    expect(exitCode, isNotNull);

    await writeJsonArtifact(
      artifactDir,
      '${platform}_harness_proof.json',
      {
        'verdict': 'pass',
        'platform': platform,
        'vmUriHost': app.vmUri.host,
        'sessionArtifactDir': artifactDir.path,
        'settlementExitCode': exitCode,
      },
    );
  } finally {
    await driver?.close();
    try {
      if (session != null && !session.stopped) {
        await session.app.stop();
        session.stopped = true;
      }
    } finally {
      await session?.logcat?.stop();
    }
  }
}
