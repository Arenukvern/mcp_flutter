// The runner-session contract expressed with resource_composition types:
// file-presence readiness (absence is liveness), typed VM-URI output,
// attach-only semantics, and stop refusal.
import 'dart:convert';
import 'dart:io';

import 'package:oka_harness/oka_harness.dart';
import 'package:resource_composition/resource_composition.dart' hide allOf;
import 'package:test/test.dart';

void main() {
  late Directory projectDir;
  late File sessionFile;

  setUp(() async {
    projectDir = await Directory.systemTemp.createTemp('oka-harness-session');
    sessionFile = File('${projectDir.path}/.flutter_mcp/runner-session.json');
    await sessionFile.parent.create(recursive: true);
  });

  tearDown(() async {
    await projectDir.delete(recursive: true);
  });

  Future<void> publishSession() async {
    await sessionFile.writeAsString(
      jsonEncode({
        'schema': 1,
        'runner': 'test',
        'vm_service_uri': 'ws://127.0.0.1:8182/abc/ws',
        'control_port': 8181,
        'device_id': 'emulator-5554',
        'pid': 4242,
        'started_at': '2026-09-27T12:00:00.000Z',
      }),
    );
  }

  test('resolves the typed vm_service_uri output from a live session',
      () async {
    await publishSession();
    final outputs = await resolveLiveSessionOutputs(projectDir.path);
    expect(
      outputs.require(runnerSessionVmUri),
      'ws://127.0.0.1:8182/abc/ws',
    );
  });

  test('file absence is the liveness signal: attach fails with the '
      'spec-v2 message', () async {
    await expectLater(
      resolveLiveSessionOutputs(projectDir.path),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('absence'), contains('liveness')),
        ),
      ),
    );
  });

  test('launch mode is refused: never a second owner', () async {
    final provider = RunnerSessionProvider(projectDir: projectDir.path);
    await expectLater(
      provider.start(
        StartRequest(
          component: runnerSessionComponent(projectDir.path),
          mode: StartMode.start,
          dependencies: ResolvedOutputs.empty,
          readinessBudget: const Duration(seconds: 1),
          cancellation: Cancellation(),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(sessionFile.existsSync(), isFalse, reason: 'nothing spawned');
  });

  test('stop is a refusal: the owning session is not ours to stop',
      () async {
    final provider = RunnerSessionProvider(projectDir: projectDir.path);
    final stop = await provider.stop(
      const ResourceRef(componentId: 'runner-session', handle: 'x'),
      grace: const Duration(milliseconds: 10),
    );
    expect(stop.disposition, StopDisposition.refused);
  });

  test('inspect reports the session ended (transport-lost) after the '
      'runner deletes its file', () async {
    final provider = RunnerSessionProvider(projectDir: projectDir.path);
    await publishSession();
    final live = await provider.inspect(
      const ResourceRef(componentId: 'runner-session', handle: 'x'),
    );
    expect(live.state, ResourceState.ready);

    await sessionFile.delete();
    final ended = await provider.inspect(
      const ResourceRef(componentId: 'runner-session', handle: 'x'),
    );
    expect(ended.state, ResourceState.stopped);
    expect(ended.cause, TerminalCause.transportLost);
  });

  test('the declared readiness carries absence-is-liveness', () {
    final readiness = runnerSessionReadiness(projectDir.path);
    expect(readiness.absenceIsLiveness, isTrue);
    expect(readiness.path, endsWith('.flutter_mcp/runner-session.json'));
  });
}
