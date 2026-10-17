import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:vm_service/vm_service.dart' as vms;
import 'package:vm_service/vm_service_io.dart' as vm_io;

Future<void> main() async {
  final httpUri = Uri.parse(Platform.environment['LA_VM_URI']!);
  // 1) full extension list via a raw vm_service connection
  final wsUri = httpUri.replace(scheme: 'ws').resolve('ws');
  final service = await vm_io.vmServiceConnectUri(wsUri.toString());
  final machine = await service.getVM();
  for (final ref in machine.isolates ?? <vms.IsolateRef>[]) {
    final iso = await service.getIsolate(ref.id!);
    final exts = iso.extensionRPCs ?? <String>[];
    if (exts.any((e) => e.startsWith('ext.mcp.toolkit'))) {
      stdout.writeln('--- toolkit isolate ${iso.name} ---');
      stdout.writeln(exts.where((e) => e.startsWith('ext.mcp.toolkit')).join('\n'));
    }
  }
  // 2) storage_state through the harness client
  final client = await VmClient.connect(httpUri);
  try {
    final res = await client.callExtension(
      'ext.mcp.toolkit.storage_state',
      args: const {},
    );
    stdout.writeln(
        'storage_state: ${const JsonEncoder.withIndent(' ').convert(res)}');
  } on Object catch (e) {
    stdout.writeln('storage_state failed: $e');
  }
  exit(0);
}
