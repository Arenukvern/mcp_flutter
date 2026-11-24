/// All-in-one Chrome showcase validation (replaces
/// `scripts/run_web_showcase_tests.sh`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:path/path.dart' as p;

final String repoRoot = p.normalize(
  p.join(p.dirname(Platform.script.toFilePath()), '..', '..', '..'),
);

String get appDir {
  final override = Platform.environment['SHOWCASE_APP_DIR']?.trim();
  if (override != null && override.isNotEmpty) {
    return p.isAbsolute(override)
        ? p.normalize(override)
        : p.join(repoRoot, override);
  }
  return p.join(repoRoot, 'showcase', 'flutter_test_app');
}

Future<void> main(List<String> arguments) async {
  final showcase = p.join(repoRoot, '.showcase');
  final out = p.join(showcase, 'tool_verify', 'web');
  final webPort = Platform.environment['WEB_PORT']?.trim() ?? '8080';
  Directory(out).createSync(recursive: true);

  stdout.writeln('[web-tests] starting chrome showcase (detach)…');
  final launchStdout = File(p.join(out, 'web-showcase.stdout'));
  final launchStderr = File(p.join(out, 'web-showcase.stderr'));

  final launch = await Process.run(
    'dart',
    ['run', p.join(repoRoot, 'packages', 'harness', 'tool', 'showcase.dart'), '--web', '--detach'],
    workingDirectory: repoRoot,
    environment: Platform.environment,
  );
  await launchStdout.writeAsString(launch.stdout as String);
  await launchStderr.writeAsString(launch.stderr as String);
  if (launch.exitCode != 0) {
    stderr.write(launchStdout.readAsStringSync());
    stderr.write(launchStderr.readAsStringSync());
    exit(launch.exitCode);
  }
  stdout.write(launchStdout.readAsStringSync());

  final wsUri = await waitForRunnerSessionVmServiceUri(maxAttempts: 30);
  if (wsUri == null) {
    stderr.writeln(
      '[web-tests] timeout reading vm_service_uri from '
      '${p.join(appDir, ".flutter_mcp", "runner-session.json")}',
    );
    await stopShowcase();
    exit(1);
  }

  stdout.writeln('[web-tests] WS_URI=$wsUri');
  final webDebugPort =
      Platform.environment['WEB_BROWSER_DEBUGGING_PORT']?.trim() ?? '9222';

  var failures = 0;

  Future<void> runStep(String name, Future<int> Function() action) async {
    stdout.writeln('\n[web-tests] === $name ===');
    final code = await action();
    if (code == 0) {
      stdout.writeln('[web-tests] PASS $name');
    } else {
      stdout.writeln(
        '[web-tests] FAIL $name (see ${p.join(out, "$name.stderr")})',
      );
      failures++;
    }
  }

  final toolkit = <String>[
    'run',
    p.join(repoRoot, 'mcp_server_dart', 'bin', 'flutter_mcp_toolkit.dart'),
    '--vm-service-uri',
    wsUri,
  ];

  await runStep('doctor', () async {
    final result = await Process.run(
      'dart',
      [...toolkit, 'doctor', '--json'],
      workingDirectory: repoRoot,
    );
    await File(p.join(out, 'doctor.stdout')).writeAsString(result.stdout as String);
    await File(p.join(out, 'doctor.stderr')).writeAsString(result.stderr as String);
    return result.exitCode;
  });

  await runStep('validate-runtime', () async {
    final validateOut = p.join(out, 'validate-runtime');
    Directory(validateOut).createSync(recursive: true);
    final result = await Process.run(
      'dart',
      [
        ...toolkit,
        '--flutter-device',
        'chrome',
        '--web-browser-debugging-port',
        webDebugPort,
        '--save-images',
        '--output-dir',
        validateOut,
        'validate-runtime',
        '--target',
        wsUri,
        '--timeout-ms',
        '60000',
      ],
      workingDirectory: repoRoot,
    );
    await File(p.join(out, 'validate-runtime.stdout'))
        .writeAsString(result.stdout as String);
    await File(p.join(out, 'validate-runtime.stderr'))
        .writeAsString(result.stderr as String);
    return result.exitCode;
  });

  await runStep('webmcp-verify', () async {
    final result = await Process.run(
      'dart',
      [
        'run',
        p.join(repoRoot, 'mcp_server_dart', 'bin', 'flutter_mcp_toolkit.dart'),
        'webmcp',
        'verify',
        '--web-port',
        webPort,
      ],
      workingDirectory: repoRoot,
    );
    await File(p.join(out, 'webmcp-verify.stdout'))
        .writeAsString(result.stdout as String);
    await File(p.join(out, 'webmcp-verify.stderr'))
        .writeAsString(result.stderr as String);
    return result.exitCode;
  });

  await runStep('webmcp-bridge-proof', () async {
    final result = await Process.run(
      'dart',
      [
        'run',
        p.join(repoRoot, 'mcp_server_dart', 'bin', 'flutter_mcp_toolkit.dart'),
        'webmcp',
        'verify',
        '--web-port',
        webPort,
        '--tool-name',
        'app_intentcall_bridge_ping',
        '--tool-args',
        '{"echo":"webmcp-proof"}',
        '--expect-result-field',
        'source',
        '--expect-result-value',
        'dart_registry',
      ],
      workingDirectory: repoRoot,
    );
    await File(p.join(out, 'webmcp-bridge-proof.stdout'))
        .writeAsString(result.stdout as String);
    await File(p.join(out, 'webmcp-bridge-proof.stderr'))
        .writeAsString(result.stderr as String);
    return result.exitCode;
  });

  await runStep('runtime-enter-text', () async {
    final evalScript =
        p.join(repoRoot, 'tool', 'evals', 'run_runtime_enter_text_greeting.dart');
    if (!File(evalScript).existsSync()) {
      await File(p.join(out, 'runtime-enter-text.stderr'))
          .writeAsString('missing $evalScript\n');
      return 1;
    }
    final result = await Process.run(
      Platform.resolvedExecutable,
      [
        'run',
        evalScript,
        '--ws-uri',
        wsUri,
        '--platform',
        'web',
        '--launch-command',
        'dart run packages/harness/tool/showcase.dart --web --detach',
        '--output',
        p.join(out, 'runtime-enter-text-greeting.json'),
      ],
      workingDirectory: repoRoot,
      environment: Platform.environment,
    );
    await File(p.join(out, 'runtime-enter-text.stdout'))
        .writeAsString(result.stdout as String);
    await File(p.join(out, 'runtime-enter-text.stderr'))
        .writeAsString(result.stderr as String);
    return result.exitCode;
  });

  await runStep('exec-sweep', () async {
    final env = Map<String, String>.from(Platform.environment)
      ..['WS_URI'] = wsUri
      ..['PLATFORM'] = 'web'
      ..['WEB_BROWSER_DEBUGGING_PORT'] = webDebugPort;
    final result = await Process.run(
      'dart',
      ['run', p.join(repoRoot, 'packages', 'harness', 'tool', 'exec_sweep.dart')],
      workingDirectory: repoRoot,
      environment: env,
    );
    await File(p.join(out, 'exec-sweep.stdout'))
        .writeAsString(result.stdout as String);
    await File(p.join(out, 'exec-sweep.stderr'))
        .writeAsString(result.stderr as String);
    return result.exitCode;
  });

  await stopShowcase();

  final summary = StringBuffer()
    ..writeln('WS_URI=$wsUri')
    ..writeln('FAILURES=$failures');
  final summaryText = summary.toString();
  stdout.write(summaryText);
  await File(p.join(out, 'summary.txt')).writeAsString(summaryText);

  if (failures > 0) {
    exit(1);
  }
  stdout.writeln('[web-tests] all web showcase tests passed');
}

Future<String?> waitForRunnerSessionVmServiceUri({required int maxAttempts}) async {
  final sessionFile = File(p.join(appDir, '.flutter_mcp', 'runner-session.json'));
  for (var i = 0; i < maxAttempts; i++) {
    if (sessionFile.existsSync()) {
      try {
        final map =
            jsonDecode(sessionFile.readAsStringSync()) as Map<String, dynamic>;
        final uri = map['vm_service_uri']?.toString().trim();
        if (uri != null && uri.isNotEmpty) {
          if (uri.startsWith('http://')) {
            return canonicalVmServiceWsUri(Uri.parse(uri)).toString();
          }
          return uri;
        }
      } on Object {
        // retry
      }
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return null;
}

Future<void> stopShowcase() async {
  await Process.run(
    'dart',
    ['run', p.join(repoRoot, 'packages', 'harness', 'tool', 'showcase.dart'), '--stop'],
    workingDirectory: repoRoot,
  );
}
