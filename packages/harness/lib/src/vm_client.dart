import 'dart:async';

import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart' as vm_io;

/// Owns the VM-service connection to one running Flutter app.
///
/// Extends the harness's control past log scraping: extension calls
/// (widget snapshot/tap/evaluate), hot reload, and extension discovery.
final class VmClient {
  VmClient._(this._service, this._mainIsolate);

  final vm.VmService _service;
  final vm.IsolateRef _mainIsolate;

  /// Connects to an http://…/#authToken= style VM service URI, verifies the
  /// main isolate is alive, and returns the client.
  static Future<VmClient> connect(final Uri httpUri) async {
    final wsUri = httpUri.replace(
      scheme: 'ws',
      path: httpUri.path.endsWith('/')
          ? '${httpUri.path}ws'
          : '${httpUri.path}/ws',
    );
    final service = await vm_io.vmServiceConnectUri(wsUri.toString());
    final vmName = await service.getVM();
    final isolates = <vm.IsolateRef>[
      ...?vmName.isolates,
    ];
    if (isolates.isEmpty) {
      throw StateError('VM at $httpUri exposes no isolates');
    }
    // The main isolate runs main(); pick the first that responds.
    for (final ref in isolates) {
      try {
        await service.getIsolate(ref.id!);
        return VmClient._(service, ref);
      } on vm.RPCError {
        continue;
      }
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
  Future<Map<String, dynamic>> callExtension(
    final String name, {
    final Map<String, Object?> args = const <String, Object?>{},
  }) async {
    final response = await _service.callServiceExtension(
      name,
      isolateId: _mainIsolate.id,
      args: args,
    );
    return response.json ?? <String, dynamic>{};
  }

  /// Evaluates an expression in the main isolate's root library context.
  Future<String> evaluate(final String expression) async {
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
