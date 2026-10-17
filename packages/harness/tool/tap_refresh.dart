import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

/// Taps the automations refresh control (found by its tooltip label)
/// and captures the populated panel.
Future<void> main(List<String> args) async {
  final out = args.isNotEmpty ? args.first : '/tmp';
  final client = await VmClient.connect(
    Uri.parse('http://127.0.0.1:58092/zhhsqmOHgUQ=/'),
  );
  final snap = await client.callExtension(ToolkitExtensions.snapshot);
  final nodes = (snap['nodes']! as List<Object?>)
      .whereType<Map<String, Object?>>()
      .toList();
  Map<String, Object?>? refresh;
  for (final n in nodes) {
    final label = (n['label'] ?? '').toString();
    if (label.toLowerCase().contains('refresh')) {
      refresh = n;
      stdout.writeln(
        'refresh: ${n['ref']} label=$label bounds=${n['bounds']}',
      );
      break;
    }
  }
  if (refresh == null) {
    for (final n in nodes) {
      final label = (n['label'] ?? '').toString();
      if (label.contains('Automations') ||
          label.contains('automation')) {
        stdout.writeln('near: ${n['ref']} [${
            n['type']}] label=$label bounds=${n['bounds']}');
      }
    }
    stderr.writeln('no refresh control found');
    exit(1);
  }
  await client.callExtension(ToolkitExtensions.tap,
      args: {'ref': refresh['ref']});
  await Future<void>.delayed(const Duration(milliseconds: 900));
  final png = await ToolkitDriver(client).screenshot();
  final file = File('$out/la-automations-populated.png');
  await file.writeAsBytes(png);
  stdout.writeln('${file.path} (${png.length} bytes)');

  final tree = const JsonEncoder.withIndent(' ').convert(
    await client.callExtension(ToolkitExtensions.snapshot),
  );
  for (final line in tree.split('\n')) {
    if (line.contains('notes-indexer') ||
        line.contains('nightly-backup')) {
      stdout.writeln('row: ${line.trim()}');
    }
  }
}
