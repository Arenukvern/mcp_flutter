// SDK blocker (documented, no UA republication in this PR):
// pub.dev universal_capture_flutter 0.2.0 uses `final` formal parameters,
// which Dart 3.13.4 rejects (`Can't have modifier 'final' here`). Behavior
// matches the hosted VmScreenshotGrabber until UA republishes.
import 'dart:convert';
import 'dart:typed_data';

import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart' as vm_io;

final class VmScreenshotGrabber {
  VmScreenshotGrabber._(this._service, this._isolateId);

  final vm.VmService _service;
  final String _isolateId;

  static Future<VmScreenshotGrabber> connect(Uri vmServiceUri) async {
    final service = await vm_io.vmServiceConnectUri(
      normalizeWsUri(vmServiceUri).toString(),
    );
    final name = await service.getVM();
    for (final ref in [...?name.isolates]) {
      try {
        final isolate = await service.getIsolate(ref.id!);
        final extensions = List<String>.from(
          isolate.extensionRPCs ?? const <String>[],
        );
        if (extensions.any((name) => name.startsWith('ext.mcp.toolkit.'))) {
          return VmScreenshotGrabber._(service, ref.id!);
        }
      } on vm.RPCError {
        continue;
      }
    }
    throw StateError('no MCP toolkit isolate at $vmServiceUri');
  }

  Future<Uint8List> grab() async {
    final response = await _service.callServiceExtension(
      'ext.mcp.toolkit.view_screenshots',
      isolateId: _isolateId,
      args: <String, String>{'compress': 'false'},
    );
    final images = (response.json?['images'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toList();
    if (images.isEmpty) {
      throw StateError('view_screenshots returned no images');
    }
    return base64Decode(images.first);
  }

  Future<void> close() => _service.dispose();

  static Uri normalizeWsUri(Uri uri) {
    if (uri.scheme == 'ws' || uri.scheme == 'wss') return uri;
    final path = uri.path.endsWith('/') ? '${uri.path}ws' : '${uri.path}/ws';
    return uri.replace(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      fragment: null,
      path: path,
    );
  }
}
