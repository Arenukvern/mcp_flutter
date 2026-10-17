import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

/// Lists every semantic node near the Automations header row so the
/// refresh control can be located (icon buttons may carry no label).
Future<void> main() async {
  final client = await VmClient.connect(
    Uri.parse('http://127.0.0.1:58092/zhhsqmOHgUQ=/'),
  );
  final snap = await client.callExtension(ToolkitExtensions.snapshot);
  final nodes = (snap['nodes']! as List<Object?>)
      .whereType<Map<String, Object?>>()
      .toList();
  for (final n in nodes) {
    final b = n['bounds'] as Map<String, Object?>?;
    if (b == null) continue;
    final cy =
        ((b['top'] as num).toDouble() + (b['bottom'] as num).toDouble()) / 2;
    if (cy > 80 && cy < 140) {
      stdout.writeln(
        '${n['ref']} [${n['type']}] '
        'center=(${((b['left'] as num).toDouble() + (b['right'] as num).toDouble()) / 2},$cy) '
        'label=${(n['label'] ?? '').toString()} '
        'actions=${n['actions']}',
      );
    }
  }
}
