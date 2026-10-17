import 'dart:async';

import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart' as vm_io;

import 'vm_service_uri.dart';

/// Owns the VM-service connection to one running Flutter app.
///
/// Extends the harness's control past log scraping: extension calls
/// (widget snapshot/tap/evaluate), hot reload, and extension discovery.
///
/// Reconnection law (measured 2026-10-05): the underlying websocket can
/// drop mid-session while the app lives on (heavy view_screenshots
/// traffic drops it reliably). vm_service self-disposes when the socket
/// closes (`streamClosed → dispose`), and every later call then throws
/// the local `-32000 Service connection disposed`. [VmClient] therefore
/// keeps its [httpUri] and re-establishes the socket on any
/// connection-level failure, ONCE per call, transparently to the caller.
final class VmClient {
  VmClient._(this.httpUri, this._service, this._mainIsolate);

  /// The http VM-service URI this client (re)connects through.
  final Uri httpUri;

  vm.VmService _service;
  vm.IsolateRef _mainIsolate;

  /// The isolate id this client is bound to (diagnostics).
  String? get boundIsolateId => _mainIsolate.id;

  /// Connects to an http://…/#authToken= style VM service URI, verifies the
  /// main isolate is alive, and returns the client.
  ///
  /// Isolate choice: the first isolate is not always the app — device
  /// launches expose engine/support isolates before (and besides) the UI
  /// isolate, and extension calls against those 404 (-32601) forever. Among
  /// responsive isolates, prefer one carrying the MCP toolkit registration;
  /// fall back to the first responsive isolate for toolkit-less apps.
  static Future<VmClient> connect(Uri httpUri) async {
    final wsUri = canonicalVmServiceWsUri(httpUri);
    final service = await vm_io.vmServiceConnectUri(wsUri.toString());
    final vmName = await service.getVM();
    final isolates = <vm.IsolateRef>[...?vmName.isolates];
    if (isolates.isEmpty) {
      throw StateError('VM at $httpUri exposes no isolates');
    }
    vm.IsolateRef? firstResponsive;
    for (final ref in isolates) {
      try {
        final isolate = await service.getIsolate(ref.id!);
        firstResponsive ??= ref;
        final extensions = List<String>.from(isolate.extensionRPCs ?? const []);
        if (extensions.any((name) => name.startsWith('ext.mcp.toolkit.'))) {
          return VmClient._(httpUri, service, ref);
        }
      } on vm.RPCError {
        continue;
      }
    }
    if (firstResponsive != null) {
      return VmClient._(httpUri, service, firstResponsive);
    }
    throw StateError('no responsive isolate at $httpUri');
  }

  /// All registered service-extension names on the main isolate.
  Future<List<String>> extensionNames() async {
    final isolate = await _service.getIsolate(_mainIsolate.id!);
    return List<String>.from(isolate.extensionRPCs ?? const <String>[]);
  }

  /// Calls a registered service extension and returns its JSON response.
  ///
  /// Args must be JSON-encodable; the app side validates types (a point
  /// coordinate sent as "364" instead of 364 fails schema validation).
  ///
  /// Three lazy recoveries, each ONE retry before rethrowing to the
  /// caller's tolerance:
  /// - a -32601 (method not found) re-binds: an early attach can be bound
  ///   to an isolate that never runs the app (the toolkit registers on
  ///   the UI isolate later), and the re-scan finds it once registration
  ///   lands;
  /// - a connection-level failure (`Service connection disposed`, socket
  ///   errors) reconnects the dropped websocket (see the reconnection
  ///   law on this class);
  /// - a [StateError] from `getVM`/`getIsolate` on a disposed connection
  ///   takes the same reconnect path.
  /// Every wire attempt is bounded by [_callTimeout]: a hung handler
  /// (e.g. a registry action awaiting something that never completes)
  /// surfaces as [TimeoutException] instead of wedging an unattended
  /// driver forever.
  Future<Map<String, dynamic>> callExtension(
    String name, {
    Map<String, Object?> args = const <String, Object?>{},
  }) async {
    try {
      return await _callExtension(name, args).timeout(_callTimeout);
    } on vm.RPCError catch (error) {
      if (error.code == -32601) {
        await _rebindToToolkitIsolate();
        return _callExtension(name, args).timeout(_callTimeout);
      }
      if (!_isConnectionLevel(error)) rethrow;
      await _reconnect();
      return _callExtension(name, args).timeout(_callTimeout);
    } on StateError {
      await _reconnect();
      return _callExtension(name, args).timeout(_callTimeout);
    }
  }

  /// Per-attempt wire bound. Generous — debug apps can stall on a
  /// breakpoint — but finite, so retry contracts (named last error, not
  /// a bare hang) actually fire.
  static const Duration _callTimeout = Duration(seconds: 30);

  /// Calls [name] until [until] accepts the response (or it simply
  /// succeeds when [until] is null), retrying the transient failures the
  /// app's boot produces: -32601 before the toolkit registers, the
  /// isolate-rebind dance a too-early attach needs, and the dropped-
  /// websocket reconnect. Exhausting [attempts] throws the LAST
  /// response/error — named data, not a bare timeout.
  Future<Map<String, dynamic>> callExtensionUntil(
    String name, {
    Map<String, Object?> args = const <String, Object?>{},
    bool Function(Map<String, dynamic> response)? until,
    int attempts = 15,
    Duration delay = const Duration(seconds: 2),
  }) async {
    Object? lastError;
    Map<String, dynamic>? lastResponse;
    for (var i = 1; i <= attempts; i++) {
      try {
        final response = await callExtension(name, args: args);
        if (until == null || until(response)) return response;
        lastResponse = response;
      } on Object catch (error) {
        lastError = error;
      }
      await Future<void>.delayed(delay);
    }
    throw StateError(
      'callExtensionUntil($name) exhausted $attempts attempts '
      '(last error: $lastError, last response: $lastResponse)',
    );
  }

  Future<Map<String, dynamic>> _callExtension(
    String name,
    Map<String, Object?> args,
  ) async {
    final response = await _service.callServiceExtension(
      name,
      isolateId: _mainIsolate.id,
      args: args,
    );
    return response.json ?? <String, dynamic>{};
  }

  /// True when [error] names a dead connection rather than an app-side
  /// refusal: the local disposed error (-32000 with the disposed
  /// message), the protocol's kConnectionDisposed (-32010), or a socket
  /// failure surfaced through the RPC channel.
  bool _isConnectionLevel(vm.RPCError error) {
    if (error.code == -32010) return true;
    if (error.code == -32000 &&
        error.message.contains('Service connection disposed')) {
      return true;
    }
    final message = error.message.toLowerCase();
    return message.contains('connection closed') ||
        message.contains('websocket') ||
        message.contains('socket');
  }

  /// Re-establishes the socket and re-binds the toolkit isolate. The old
  /// service is already self-disposed by vm_service when the socket
  /// dropped; nothing to cancel here.
  Future<void> _reconnect() async {
    final wsUri = canonicalVmServiceWsUri(httpUri);
    _service = await vm_io.vmServiceConnectUri(wsUri.toString());
    await _rebindToToolkitIsolate();
  }

  /// Re-scans the VM's isolates and re-binds to one carrying the MCP
  /// toolkit registration. No-op when none does (the current binding
  /// stays — callers see the same -32601 as before).
  Future<void> _rebindToToolkitIsolate() async {
    final vmName = await _service.getVM();
    for (final ref in [...?vmName.isolates]) {
      try {
        final isolate = await _service.getIsolate(ref.id!);
        final extensions = List<String>.from(isolate.extensionRPCs ?? const []);
        if (extensions.any((name) => name.startsWith('ext.mcp.toolkit.'))) {
          _mainIsolate = ref;
          return;
        }
      } on vm.RPCError {
        continue;
      }
    }
  }

  /// Evaluates an expression in the main isolate's root library context.
  Future<String> evaluate(String expression) async {
    final isolate = await _service.getIsolate(_mainIsolate.id!);
    final response = await _service.evaluate(
      isolate.id!,
      isolate.rootLib!.id!,
      expression,
    );
    final ref = response as vm.InstanceRef;
    return ref.valueAsString ?? '<complex ${ref.kind}>';
  }

  /// Hot-reloads the app; returns whether any sources were recompiled.
  ///
  /// Note: this raw `reloadSources` call cannot compile — when the app was
  /// launched without an owning `flutter run`/`flutter attach` session it
  /// reports success with zero changed sources. Treat `true` as "asked",
  /// not "recompiled" (see mcp_flutter ADR-0014 for the honest-reload
  /// contract the MCP server implements on top).
  Future<bool> hotReload() async {
    final report = await _service.reloadSources(_mainIsolate.id!);
    return report.success ?? false;
  }

  Future<void> dispose() async {
    _service.dispose();
  }
}
