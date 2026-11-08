@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:oka_harness/oka_harness.dart';
import 'package:test/test.dart';
import '../support/linux_bounded_flutter_run.dart';
import '../support/native_layer_evidence.dart';
import '../support/vm_screenshot_grabber_sdk_compat.dart';

void main() {
  final runAndroid =
      Platform.environment['RUN_NATIVE_FLUTTER_LAYER_ANDROID'] == '1';
  final runLinux =
      Platform.environment['RUN_NATIVE_FLUTTER_LAYER_LINUX'] == '1';

  group('native flutter_layer capture (SDK owners)', () {
  final repoRoot = harnessRepoRoot();
  final appDir = showcaseFlutterTestApp(repoRoot);
  final artifactDir = nativeCaptureArtifactDir();

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
      'Android: oka dev owns lifecycle; VmScreenshotGrabber + CLI flutter_layer',
      () => _runNativeCapture(
        platform: 'android',
        artifactDir: artifactDir,
        launch: () async {
          final deviceId = Platform.environment['ANDROID_SERIAL'];
          final target = AndroidAppTarget(
            projectDir: appDir.path,
            deviceId: deviceId,
            logcat: true,
          );
          return target.launch();
        },
      ),
      tags: ['native-android'],
      skip: runAndroid
          ? false
          : 'Set RUN_NATIVE_FLUTTER_LAYER_ANDROID=1 (and oka + emulator)',
      timeout: const Timeout(Duration(minutes: 35)),
    );

    test(
      'Linux: runBounded flutter --machine owns lifecycle; grabber + CLI',
      () => _runNativeCapture(
        platform: 'linux',
        artifactDir: artifactDir,
        launch: () => LinuxBoundedFlutterRunTarget(
          projectDir: appDir.path,
        ).launch(),
      ),
      tags: ['native-linux'],
      skip: runLinux ? false : 'Set RUN_NATIVE_FLUTTER_LAYER_LINUX=1',
      timeout: const Timeout(Duration(minutes: 20)),
    );
  });
}

Future<void> _runNativeCapture({
  required String platform,
  required Directory artifactDir,
  required Future<LaunchedApp> Function() launch,
}) async {
  final repoRoot = harnessRepoRoot();
  final appDir = showcaseFlutterTestApp(repoRoot);

  final pubGet = await Process.run(
    'flutter',
    ['pub', 'get'],
    workingDirectory: appDir.path,
  );
  expect(pubGet.exitCode, 0, reason: '${pubGet.stderr}\n${pubGet.stdout}');

  LaunchedApp? app;
  ToolkitDriver? driver;
  VmScreenshotGrabber? grabber;

  try {
    app = await launch();
    await vmHandshake(app.vmUri);

    grabber = await VmScreenshotGrabber.connect(app.vmUri);
    driver = await attachDriver(app);

    final before = await writePng(
      artifactDir,
      '${platform}_before_increment.png',
      await grabber.grab(),
    );
    await driver.perform(const ClickAction(name: 'Increment'));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final after = await writePng(
      artifactDir,
      '${platform}_after_increment.png',
      await grabber.grab(),
    );

    final pixelProof = analyzePngPair(before, after);
    await writeJsonArtifact(artifactDir, '${platform}_pixel_proof.json', {
      ...pixelProof,
      'captureBackend': captureBackendFlutterLayerVm,
      'captureImplementation': captureImplementationAppLayerTree,
      'observer': 'VmScreenshotGrabber.compress_false',
    });
    expect(pixelProof['verdict'], 'pass', reason: '$pixelProof');

    final cli = await runToolkitCliGetScreenshots(
      repoRoot: repoRoot,
      vmServiceUri: app.vmUri,
    );
    await writeJsonArtifact(artifactDir, '${platform}_cli_get_screenshots.json', cli);
    expect(cli['ok'], isTrue, reason: '$cli');
    expect(cli['captureMode'], 'flutter_layer');
    expect(cli['captureBackend'], captureBackendFlutterLayerVm);
    expect(cli['captureImplementation'], captureImplementationAppLayerTree);
    expect(cli['imageCount'], greaterThan(0));

    final renderer = rendererVerdictFromLogs(app.stdout, platform: platform);
    await writeJsonArtifact(
      artifactDir,
      '${platform}_renderer_verdict.json',
      renderer,
    );

    await grabber.close();
    grabber = null;
    await driver.close();
    driver = null;

    final exitCode = await app.stop();
    expect(exitCode, anyOf(0, 1, -1)); // deliberate stop may be !ok while settled

    await writeJsonArtifact(
      artifactDir,
      '${platform}_harness_proof.json',
      {
        'verdict': 'pass',
        'platform': platform,
        'vmUriHost': app.vmUri.host,
        'sessionArtifactDir': artifactDir.path,
      },
    );
  } finally {
    await grabber?.close();
    await driver?.close();
    await app?.stop();
  }
}
