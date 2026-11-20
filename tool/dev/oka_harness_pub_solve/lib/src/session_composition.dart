/// The runner-session contract expressed with resource_composition types
/// (ADR-0026 R3.1): the published `.flutter_mcp/runner-session.json` is a
/// component whose readiness is `FilePresent(..., absenceIsLiveness: true)`
/// and whose typed output is the forwarded `vm_service_uri`.
///
/// The provider here is **attach-only, ownership-free** — the exact
/// `driverForLiveSession` semantics of ADR-0027: it never spawns anything
/// (a second owner is the bug class mcp_flutter ADR-0014 removed), its
/// stop is a refusal (the owning `oka dev` session is not ours to stop),
/// and its reconcile reads file presence per the spec-v2 liveness rule.
library;

import 'package:oka_android/oka_android.dart';
import 'package:resource_composition/resource_composition.dart';

/// Typed output: the forwarded host-reachable VM service endpoint.
const runnerSessionVmUri = OutputRef<String>('runner-session.vm_service_uri');

/// The declared readiness for a live runner session: the discovery file
/// exists — and, being writer-owned and deleted at exit, its absence is
/// the liveness signal (mcp_flutter ADR-0014 spec v2).
FilePresent runnerSessionReadiness(String projectDir) =>
    FilePresent('$projectDir/.flutter_mcp/runner-session.json');

/// Attach-only provider over the published runner-session contract.
final class RunnerSessionProvider implements ResourceProvider {
  const RunnerSessionProvider({required this.projectDir});

  /// Flutter project directory whose `.flutter_mcp/` holds the contract.
  final String projectDir;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        attach: true,
        readinessProbe: true,
      );

  @override
  Future<StartReport> start(StartRequest request) async {
    if (request.mode == StartMode.start) {
      throw ArgumentError(
        'RunnerSessionProvider is attach-only: launching a second owner is '
        'the bug class ADR-0014 removed. Use AndroidAppTarget to bring the '
        'session up.',
      );
    }
    final session = readRunnerSessionFile(projectDir);
    if (session == null) {
      throw StateError(
        'no live runner session at $projectDir — '
        '${runnerSessionReadiness(projectDir).path} is absent, and absence '
        'is the liveness signal',
      );
    }
    return StartReport(
      ref: ResourceRef(
        componentId: request.component.id,
        handle: 'runner-session:$projectDir',
        pid: session.pid,
      ),
      attached: true,
      outputs: ResolvedOutputs({runnerSessionVmUri.id: session.vmServiceUri}),
    );
  }

  @override
  Future<Observation> inspect(ResourceRef ref) async {
    final session = readRunnerSessionFile(projectDir);
    if (session == null) {
      return const Observation(
        state: ResourceState.stopped,
        cause: TerminalCause.transportLost,
        message: 'discovery file absent — the owning session ended',
      );
    }
    return Observation(
      state: ResourceState.ready,
      message: 'control port ${session.controlPort} (the TCP probe is the '
          "consumer's secondary check)",
    );
  }

  @override
  Future<StopReport> stop(
    ResourceRef ref, {
    required Duration grace,
  }) async =>
      const StopReport(
        disposition: StopDisposition.refused,
        message: 'the owning `oka dev` session is not ours to stop; use '
            '`oka stop` or end the session',
      );

  @override
  Future<Observation> reconcile(ResourceRef ref) => inspect(ref);
}

/// The live runner session as a composition component: declared readiness
/// ([runnerSessionReadiness]) plus the typed VM-URI output, attach-only.
Component runnerSessionComponent(String projectDir) => Component(
      id: 'runner-session',
      provider: RunnerSessionProvider(projectDir: projectDir),
      readiness: runnerSessionReadiness(projectDir),
      provides: const [runnerSessionVmUri],
    );

/// Resolves the live session's typed outputs — attach, no ownership.
/// Throws [StateError] when no session is live.
Future<ResolvedOutputs> resolveLiveSessionOutputs(
  String projectDir,
) async {
  final component = runnerSessionComponent(projectDir);
  final report = await component.provider.start(
    StartRequest(
      component: component,
      mode: StartMode.attach,
      dependencies: ResolvedOutputs.empty,
      readinessBudget: const Duration(seconds: 5),
      cancellation: Cancellation(),
    ),
  );
  return report.outputs;
}
