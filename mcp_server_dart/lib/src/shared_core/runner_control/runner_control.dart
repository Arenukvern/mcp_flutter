// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:meta/meta.dart';

/// Delegation seam between the toolkit and the dev session that owns the
/// running app (an EXTERNAL runner process, discovered via its session
/// file — see `ExternalSessionRunnerControl`).
///
/// The owning session is the only compile-capable channel: kernel compilation
/// is always the runner's job, and a second attach session would kill the
/// first. When a [RunnerControl] reports [isAlive], hot reload / hot restart
/// must be delegated to it instead of (or in addition to) talking to the VM
/// service directly.
///
/// See `docs/guides/dev-session-delegation-roadmap.mdx` ("Do not" list) for
/// the rationale.
abstract interface class RunnerControl {
  /// Human-readable runner identity used in results.
  ///
  /// For file-discovered sessions this is the runner's own display metadata
  /// (the discovery file's `runner` field) — never a toolkit-side constant.
  String get runnerName;

  /// Whether an owning dev session is live right now.
  ///
  /// Must be cheap and side-effect free: it is consulted before every hot
  /// reload / hot restart command.
  Future<bool> isAlive();

  /// Drives a hot reload through the owning session and awaits the ACTUAL
  /// outcome (not a fire-and-forget request).
  Future<RunnerControlOutcome> reload();

  /// Drives a hot restart through the owning session and awaits the ACTUAL
  /// outcome (not a fire-and-forget request).
  Future<RunnerControlOutcome> restart();

  /// The VM service websocket URI of the app owned by the session, or null
  /// when no live session is known.
  ///
  /// Used as a connection fallback so the toolkit can attach to an app that
  /// port-scan / machine discovery cannot see.
  Future<String?> liveVmServiceUri();
}

/// Result of a delegated [RunnerControl.reload] / [RunnerControl.restart].
@immutable
final class RunnerControlOutcome {
  const RunnerControlOutcome({
    required this.ok,
    this.error,
    this.fallback = false,
    this.sessionRelaunched = false,
    this.vmServiceUri,
    this.raw = const <String, Object?>{},
  });

  /// Whether the delegated operation actually succeeded.
  final bool ok;

  /// Human-readable, actionable fix when [ok] is false.
  final String? error;

  /// The runner reported its attach-mode fallback (relaunch + re-attach)
  /// triggered.
  final bool fallback;

  /// The control connection closed mid-operation (relaunch fallback) and a
  /// NEW session was detected by re-reading the discovery file. The app
  /// connection must be re-established against [vmServiceUri]; the operation
  /// itself must NOT be retried.
  final bool sessionRelaunched;

  /// VM service websocket URI from the (re-read) discovery file, when known.
  final String? vmServiceUri;

  /// The raw runner response payload, for diagnostics.
  final Map<String, Object?> raw;
}

/// Default no-op runner: every query answers "not alive", so the toolkit
/// keeps its legacy behavior (direct VM-service reload/restart attempts).
final class NoneRunnerControl implements RunnerControl {
  const NoneRunnerControl();

  @override
  String get runnerName => 'none';

  @override
  Future<bool> isAlive() async => false;

  @override
  Future<RunnerControlOutcome> reload() async => const RunnerControlOutcome(
    ok: false,
    error: 'No runner control configured; nothing to delegate to.',
  );

  @override
  Future<RunnerControlOutcome> restart() async => const RunnerControlOutcome(
    ok: false,
    error: 'No runner control configured; nothing to delegate to.',
  );

  @override
  Future<String?> liveVmServiceUri() async => null;
}

/// Thrown when the runner discovery file cannot be used (missing, corrupt, or
/// written by an incompatible schema).
final class RunnerControlException implements Exception {
  const RunnerControlException(this.message);

  final String message;

  @override
  String toString() => message;
}
