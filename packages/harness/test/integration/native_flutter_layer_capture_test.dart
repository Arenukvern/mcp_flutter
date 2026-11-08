@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:image/image.dart' as img;
import 'package:oka_harness/oka_harness.dart';
import 'package:test/test.dart';

import '../support/bounded_subprocess_stop.dart';
import '../support/android_oka_dev_argv_diagnostics.dart';
import '../support/android_owned_session_stop.dart';
import '../support/linux_bounded_flutter_run.dart';
import '../support/native_capture_session_cleanup.dart';
import '../support/native_layer_capture_layout.dart';
import '../support/native_layer_evidence.dart';
import '../support/native_layer_failure_artifacts.dart';
import '../support/native_layer_oka_diagnostics.dart';
import '../support/session_settlement.dart';

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
          final okaBin = Platform.environment['OKA_BIN'] ?? 'oka';
          final okaPinSha = Platform.environment['OKA_CONSUMER_PIN_SHA'];
          await writeJsonArtifact(
            artifactDir,
            'android_oka_dev_launch_intent.json',
            {
              ...androidOkaDevLaunchIntent(
                okaBin: okaBin,
                projectDir: appDir.path,
                deviceId: deviceId,
              ),
              'consumerCutoverPlan':
                  'docs/evidence/native_layer_oka_consumer_cutover_plan.md',
              'okaConsumerPinSha': okaPinSha,
              'shellWorkaroundRemoved': true,
            },
          );
          final usePrebuild =
              Platform.environment['OKA_ANDROID_USE_PREBUILD'] == '1';
          try {
            await assertOkaAndroidDevPreflight(
              projectDir: appDir.path,
              artifactDir: artifactDir,
            );
          } on StateError {
            if (usePrebuild) {
              rethrow;
            }
            final buildTrace = await runOkaAndroidManifestBuildTraced(
              projectDir: appDir.path,
              okaBin: okaBin,
            );
            await writeJsonArtifact(
              artifactDir,
              'android_oka_build_trace.json',
              buildTrace,
            );
            if (buildTrace['exitCode'] != 0 ||
                buildTrace['checkDevSessionOk'] != true) {
              throw StateError(
                'oka build apk --debug failed manifest lifecycle '
                '(RecordRunSessionStep / checkDevSession):\n'
                '${jsonEncode(buildTrace)}',
              );
            }
            await assertOkaAndroidDevPreflight(
              projectDir: appDir.path,
              artifactDir: artifactDir,
            );
          }
          final target = AndroidAppTarget(
            projectDir: appDir.path,
            deviceId: deviceId,
            logcat: false,
            okaBin: okaBin,
            sessionTimeout: const Duration(minutes: 5),
          );
          final app = await target.launch(build: false);
          return _OwnedSession(
            app: app,
            logTap: combinedTap,
            appTap: app.stdout,
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
          final target = LinuxBoundedFlutterRunTarget(
            projectDir: appDir.path,
            extraArgs: extraArgs,
          );
          final app = await target.launch();
          for (final line in app.stdout.lines) {
            tap.add(line);
          }
          return _OwnedSession(
            app: app,
            logTap: tap,
            appTap: app.stdout,
            linuxTarget: target,
          );
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
    this.linuxTarget,
  });
  final LaunchedApp app;
  final LogTap logTap;
  final LogTap appTap;
  final LinuxBoundedFlutterRunTarget? linuxTarget;
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

  AndroidEngineLogcatSession? logcat;
  _OwnedSession? session;
  ToolkitDriver? driver;
  SubprocessStopVerdict? logcatStopVerdict;
  AndroidOkaSessionSettlement? androidSettlement;
  BoundedSessionSettlement? linuxSettlement;
  int? androidStopExitCode;

  await runWithPreservedPrimaryFailure<void>(
    body: () async {
      if (platform == 'android') {
        final deviceId = Platform.environment['ANDROID_SERIAL'];
        if (deviceId == null || deviceId.isEmpty) {
          throw StateError('ANDROID_SERIAL is required for Android native proof');
        }
        logcat = await AndroidEngineLogcatSession.start(
          deviceId: deviceId,
          sink: combinedTap,
        );
      }

      session = await launch(combinedTap);
      final owned = session!;
      final app = owned.app;
      await vmHandshake(app.vmUri);
      final activeDriver = await attachDriver(app);
      driver = activeDriver;

      final counterBefore = await counterFromDriver(activeDriver);
      expect(counterBefore, 0);

      final beforeBytes = await activeDriver.screenshot();
      final before = await writePng(
        artifactDir,
        '${platform}_before_increment.png',
        beforeBytes,
      );
      final layout = await resolveNativeCaptureLayout(
        activeDriver,
        _imageWidth(beforeBytes),
        _imageHeight(beforeBytes),
      );

      await tapIncrementButton(activeDriver);
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      final counterAfter = await counterFromDriver(activeDriver);
      final afterBytes = await activeDriver.screenshot();
      final after = await writePng(
        artifactDir,
        '${platform}_after_increment.png',
        afterBytes,
      );

      final pixelProof = analyzeCapturePair(
        before: before,
        after: after,
        counterBefore: counterBefore,
        counterAfter: counterAfter,
        layout: layout,
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
        driverLayout: layout,
      );
      await writeJsonArtifact(
        artifactDir,
        '${platform}_cli_capture_proof.json',
        cliProof,
      );
      expect(cliProof['verdict'], 'pass', reason: '$cliProof');

      final renderer = rendererVerdictFromLogs(
        owned.combinedLogLines,
        platform: platform,
      );
      await writeJsonArtifact(
        artifactDir,
        '${platform}_renderer_verdict.json',
        renderer,
      );
      expect(renderer['platformRendererAccepted'], isTrue, reason: '$renderer');
      if (platform == 'android') {
        expect(renderer['activeRendererBackend'], 'impeller', reason: '$renderer');
      } else if (platform == 'linux') {
        expect(renderer['rendererAccepted'], isTrue, reason: '$renderer');
        expect(
          renderer['activeRendererBackend'],
          isIn(['impeller', 'skia']),
          reason: '$renderer',
        );
      }

      await activeDriver.close();
      driver = null;

      final ownerPid = app.process?.pid;
      androidStopExitCode = await app.stop();
      owned.stopped = true;

      linuxSettlement = owned.linuxTarget?.lastSettlement;
      if (linuxSettlement != null) {
        expect(
          linuxSettlement!.physicallySettled,
          isTrue,
          reason: '${linuxSettlement!.toJson()}',
        );
        expect(linuxSettlement!.survivors, isEmpty, reason: '${linuxSettlement!.toJson()}');
        expect(
          linuxSettlement!.shutdownTruthful,
          isTrue,
          reason:
              'Linux shutdown: cooperative app.stop ack or documented '
              'bounded-settlement fallback: ${linuxSettlement!.toJson()}',
        );
      }

      if (platform == 'android') {
        androidSettlement = await recordAndroidOkaStopSettlement(
          exitCode: androidStopExitCode!,
          processPid: ownerPid,
          projectDir: appDir.path,
        );
        expect(
          androidSettlement!.processSettled,
          isTrue,
          reason: '${androidSettlement!.toJson()}',
        );
        expect(
          androidSettlement!.runnerSessionAbsent,
          isTrue,
          reason: '${androidSettlement!.toJson()}',
        );
      }

      await writeJsonArtifact(
        artifactDir,
        '${platform}_harness_proof.json',
        {
          'verdict': 'pass',
          'platform': platform,
          'vmUriHost': app.vmUri.host,
          'sessionArtifactDir': artifactDir.path,
          'linuxSettlement': linuxSettlement?.toJson(),
          'androidSettlement': androidSettlement?.toJson(),
          'androidStopExitCode': androidStopExitCode,
          'logcatStop': logcatStopVerdict?.toJson(),
        },
      );
    },
    cleanupSteps: [
      (
        'driver.close',
        () async {
          if (driver == null) return;
          await driver!.close();
          driver = null;
        },
      ),
      (
        'app.stop',
        () async {
          if (session == null || session!.stopped) return;
          final app = session!.app;
          final exit = await app.stop();
          session!.stopped = true;
          if (platform == 'android' && androidSettlement == null) {
            androidStopExitCode = exit;
            androidSettlement = await recordAndroidOkaStopSettlement(
              exitCode: exit,
              processPid: app.process?.pid,
              projectDir: appDir.path,
            );
          }
        },
      ),
      (
        'logcat.stop',
        () async {
          if (logcat == null) return;
          logcatStopVerdict = await logcat!.stop();
        },
      ),
    ],
    onOutcome: (outcome) async {
      if (!outcome.hasPrimary && !outcome.hasCleanupFailures) return;
      await persistNativeCaptureFailureBundle(
        artifactDir: artifactDir,
        platform: platform,
        outcome: outcome,
        combinedLogTap: combinedTap,
        projectDir: platform == 'android' ? appDir.path : null,
      );
    },
  );
}

int _imageWidth(Uint8List png) {
  final decoded = img.decodeImage(png);
  if (decoded == null) throw StateError('png_decode_failed');
  return decoded.width;
}

int _imageHeight(Uint8List png) {
  final decoded = img.decodeImage(png);
  if (decoded == null) throw StateError('png_decode_failed');
  return decoded.height;
}
