/// Android oka 0.9.1 build ↔ dev manifest diagnostics (consumer boundary).
///
/// Uses hosted [checkDevSession] / [devLoopDoctorChecks] — no oka patches.
library;

import 'dart:convert';
import 'dart:io';

import 'package:oka_android/oka_android.dart';
import 'package:path/path.dart' as p;

/// Scans `.oka_cache/build/**` for APKs and adjacent `run_session.json`.
Future<Map<String, Object?>> snapshotOkaAndroidArtifactTree(String projectDir) async {
  final buildRoot = Directory(p.join(projectDir, '.oka_cache', 'build'));
  final entries = <Map<String, Object?>>[];
  if (buildRoot.existsSync()) {
    await for (final entity in buildRoot.list(recursive: true)) {
      if (entity is! File) continue;
      final base = p.basename(entity.path);
      if (!base.endsWith('.apk') && base != runSessionFileName) continue;
      final stat = await entity.stat();
      final adjacent = <String, Object?>{};
      if (base.endsWith('.apk')) {
        final manifest = File(
          p.join(p.dirname(entity.path), runSessionFileName),
        );
        adjacent['run_session_json'] = manifest.existsSync()
            ? {
                'path': manifest.path,
                'bytes': manifest.lengthSync(),
              }
            : null;
        final embedded = RunSession.forApk(entity.path);
        adjacent['parsed_session'] = embedded == null
            ? null
            : {
                'apk_path_field': embedded.apkPath,
                'build_mode': embedded.buildMode,
                'engine_revision': embedded.engineRevision,
                'flutter_sdk_path': embedded.flutterSdkPath,
              };
      }
      entries.add({
        'path': entity.path,
        'relative': p.relative(entity.path, from: projectDir),
        'bytes': stat.size,
        'modifiedMs': stat.modified.millisecondsSinceEpoch,
        if (adjacent.isNotEmpty) ...adjacent,
      });
    }
  }
  entries.sort(
    (a, b) => (b['modifiedMs'] as int).compareTo(a['modifiedMs'] as int),
  );
  final runnerSession = File(p.join(projectDir, '.flutter_mcp', 'runner-session.json'));
  return {
    'projectDir': projectDir,
    'buildRootExists': buildRoot.existsSync(),
    'artifacts': entries,
    'runner_session_json': runnerSession.existsSync()
        ? {
            'path': runnerSession.path,
            'bytes': runnerSession.lengthSync(),
          }
        : null,
  };
}

Future<Map<String, Object?>> resolveOkaCliMetadata({String okaBin = 'oka'}) async {
  final version = await Process.run(okaBin, ['--version']);
  final which = await Process.run('bash', ['-lc', 'command -v $okaBin']);
  return {
    'okaBinRequested': okaBin,
    'okaResolvedPath': '${which.stdout}'.trim(),
    'okaVersionStdout': '${version.stdout}'.trim(),
    'okaVersionStderr': '${version.stderr}'.trim(),
    'okaVersionExitCode': version.exitCode,
  };
}

List<String> _okaBuildApkDebugProcessArgv({
  required String okaBin,
  required Map<String, String> mergedEnv,
}) {
  final abi = mergedEnv['OKA_ANDROID_BUILD_ABI']?.trim() ?? '';
  final tail = <String>['build', 'apk', '--debug'];
  if (abi.isNotEmpty) {
    tail.addAll(['--abi', abi]);
  }
  return [okaBin, ...tail];
}

/// Runs `oka build apk --debug` with argv/cwd logging and pre/post trees.
///
/// Set [OKA_ANDROID_BUILD_ABI] (e.g. `x86_64`) when the install target is a
/// CI x86_64 AVD; default oka/engine splits may omit that ABI on amd64 hosts.
Future<Map<String, Object?>> runOkaAndroidManifestBuildTraced({
  required String projectDir,
  required String okaBin,
  Map<String, String> environment = const {},
  bool runInShell = false,
}) async {
  final mergedEnv = environment.isEmpty
      ? Map<String, String>.from(Platform.environment)
      : <String, String>{...Platform.environment, ...environment};
  final processArgv = _okaBuildApkDebugProcessArgv(
    okaBin: okaBin,
    mergedEnv: mergedEnv,
  );
  final argv = List<String>.from(processArgv);
  final pre = await snapshotOkaAndroidArtifactTree(projectDir);
  final okaMeta = await resolveOkaCliMetadata(okaBin: okaBin);
  final started = DateTime.now().toUtc().toIso8601String();
  final okaTail = processArgv.sublist(1);
  final build = runInShell
      ? await Process.run(
          okaBin,
          okaTail,
          workingDirectory: projectDir,
          environment: mergedEnv,
          runInShell: true,
        )
      : await Process.run(
          'bash',
          processArgv,
          workingDirectory: projectDir,
          environment: mergedEnv,
        );
  final post = await snapshotOkaAndroidArtifactTree(projectDir);
  final manifestPath = p.join(
    projectDir,
    '.oka_cache',
    'build',
    'debug',
    runSessionFileName,
  );
  final apkPath = p.join(
    projectDir,
    '.oka_cache',
    'build',
    'debug',
    'app-debug.apk',
  );
  final check = await checkDevSession(projectPath: projectDir);
  return {
    'startedAt': started,
    'argv': argv,
    'workingDirectory': projectDir,
    'runInShell': runInShell,
    'exitCode': build.exitCode,
    'stdout': '${build.stdout}',
    'stderr': '${build.stderr}',
    'expectedManifestPath': manifestPath,
    'expectedApkPath': apkPath,
    'manifestExists': File(manifestPath).existsSync(),
    'apkExists': File(apkPath).existsSync(),
    'preArtifactTree': pre,
    'postArtifactTree': post,
    'checkDevSessionOk': check.ok,
    'checkDevSessionRefusal': check.refusal,
    'checkDevSessionLines': check.lines,
    'okaCliGlobal': okaMeta,
  };
}

/// After [reactivecircus/android-emulator-runner] boot, `package` / activity
/// services may still be down (API 34+). Poll `pm path` per okhttp/dotnet pattern.
Future<Map<String, Object?>> waitForAndroidPackageManagerReady({
  String? deviceId,
  Duration timeout = const Duration(minutes: 3),
  Duration pollInterval = const Duration(seconds: 5),
}) async {
  final serial = deviceId ?? Platform.environment['ANDROID_SERIAL'];
  if (serial == null || serial.isEmpty) {
    throw StateError('ANDROID_SERIAL required for emulator readiness wait');
  }
  final adb = Platform.environment['ADB'] ?? 'adb';
  final started = DateTime.now().toUtc();
  final attempts = <Map<String, Object?>>[];

  while (DateTime.now().difference(started) < timeout) {
    final boot = await Process.run(
      adb,
      ['-s', serial, 'shell', 'getprop', 'sys.boot_completed'],
    );
    final bootCompleted = '${boot.stdout}'.trim() == '1';
    final pmPath = await Process.run(
      adb,
      ['-s', serial, 'shell', 'pm', 'path', 'com.android.shell'],
    );
    final pmOk = pmPath.exitCode == 0 && '${pmPath.stdout}'.contains('package:');
    attempts.add({
      'at': DateTime.now().toUtc().toIso8601String(),
      'bootCompleted': bootCompleted,
      'packageManagerOk': pmOk,
      'pmPathExitCode': pmPath.exitCode,
      'pmStderrTail': '${pmPath.stderr}'.trim().split('\n').take(3).join('\n'),
    });
    if (bootCompleted && pmOk) {
      return {
        'deviceId': serial,
        'ready': true,
        'elapsedMs': DateTime.now().difference(started).inMilliseconds,
        'attempts': attempts,
      };
    }
    await Future<void>.delayed(pollInterval);
  }

  return {
    'deviceId': serial,
    'ready': false,
    'elapsedMs': DateTime.now().difference(started).inMilliseconds,
    'attempts': attempts,
    'reason':
        'package manager not ready (cmd: Can\'t find service: package / boot incomplete)',
  };
}

/// Fail-closed preflight before spawning `oka dev android` (no multi-minute wait).
Future<Map<String, Object?>> okaAndroidDevPreflightReport({
  required String projectDir,
  bool checkDevice = false,
}) async {
  final tree = await snapshotOkaAndroidArtifactTree(projectDir);
  final doctor = await devLoopDoctorChecks(
    projectPath: projectDir,
    checkDevice: checkDevice,
  );
  final session = await checkDevSession(projectPath: projectDir);
  return {
    'artifactTree': tree,
    'doctorOk': doctor.ok,
    'doctorBlocking': doctor.blocking,
    'doctorLines': doctor.lines,
    'checkDevSessionOk': session.ok,
    'checkDevSessionRefusal': session.refusal,
    'checkDevSessionLines': session.lines,
    'newestApk': await findNewestBuiltApk(projectDir),
  };
}

/// Throws [StateError] with JSON diagnostics when manifest / preflight refuses.
Future<void> assertOkaAndroidDevPreflight({
  required String projectDir,
  Directory? artifactDir,
  String? diagnosticsFilePrefix,
}) async {
  final report = await okaAndroidDevPreflightReport(projectDir: projectDir);
  final sessionOk = report['checkDevSessionOk'] == true;
  final doctorBlocking = report['doctorBlocking'] == true;
  if (sessionOk && !doctorBlocking) {
    return;
  }
  final encoded = const JsonEncoder.withIndent('  ').convert(report);
  if (artifactDir != null) {
    final name = diagnosticsFilePrefix == null
        ? 'android_oka_dev_preflight.json'
        : '${diagnosticsFilePrefix}_oka_dev_preflight.json';
    await File(p.join(artifactDir.path, name)).writeAsString('$encoded\n');
  }
  throw StateError(
    'oka dev android preflight refused (hosted checkDevSession / doctor):\n'
    '$encoded',
  );
}
