import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

/// Navigate to Settings if needed, tap the automations pane's refresh
/// button (the icon button right of the "Automations" header), capture.
Future<void> main(List<String> args) async {
  final out = args.isNotEmpty ? args.first : '/tmp';
  final vmUri = Platform.environment['LA_VM_URI']!;
  final client = await VmClient.connect(Uri.parse(vmUri));
  final driver = ToolkitDriver(client);
  Future<T> step<T>(String name, Future<T> Function() body) =>
      body().timeout(const Duration(seconds: 25), onTimeout: () {
        stderr.writeln('TIMEOUT at step: $name');
        exit(3);
      });
  Future<Map<String, dynamic>> ext(
    String name, {
    Map<String, Object?> args = const <String, Object?>{},
  }) =>
      step(name, () => client.callExtension(name, args: args));

  try {
    Future<(List<Map<String, Object?>>, String?)> grab() async {
      final tree =
          await step('snapshot', () => ext(ToolkitExtensions.snapshot));
      final nodes = (tree['nodes']! as List<Object?>)
          .whereType<Map<String, Object?>>()
          .toList();
      String? y;
      for (final n in nodes) {
        if (n['type'] == 'text' && n['label'] == 'Automations') {
          y = '${(n['center']! as Map<String, Object?>)['y']}';
        }
      }
      return (nodes, y);
    }

    var (nodes, headerY) = await grab();
    if (headerY == null) {
      final buttons = nodes.where((n) => n['type'] == 'button').toList();
      final gear = buttons.length > 3 ? buttons[3] : buttons.last;
      await step('tap-gear', () {
        return ext(
            ToolkitExtensions.tap, args: {'ref': gear['ref']! as String});
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      (nodes, headerY) = await grab();
    }
    if (headerY == null) {
      stderr.writeln('Automations header not found');
      exit(2);
    }
    final y = double.parse(headerY);
    Map<String, Object?>? refresh;
    for (final n in nodes) {
      if (n['type'] != 'button') continue;
      final center = n['center']! as Map<String, Object?>;
      final cx = (center['x']! as num).toDouble();
      final cy = (center['y']! as num).toDouble();
      if ((cy - y).abs() < 25 && cx > 550) refresh = n;
    }
    if (refresh == null) {
      stderr.writeln('refresh button not found next to header');
      exit(2);
    }
    stdout.writeln('tapping refresh ${refresh['ref']}');
    await step('tap-refresh', () {
      return ext(ToolkitExtensions.tap, args: {'ref': refresh!['ref']});
    });
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final panel = const JsonEncoder.withIndent(' ')
        .convert(await step('snapshot', () => ext(ToolkitExtensions.snapshot)));
    await File('$out/la-supervisor-semantic.json').writeAsString(panel);
    var hit = false;
    for (final line in panel.split('\n')) {
      if (line.contains('"label"')) {
        final label = line.trim();
        if (label.contains('notes-indexer') ||
            label.contains('nightly-backup') ||
            label.contains('not a valid document') ||
            label.contains('No automations') ||
            label.contains('Automations')) {
          stdout.writeln('panel: $label');
          if (label.contains('notes-indexer') ||
              label.contains('nightly-backup') ||
              label.contains('not a valid document')) {
            hit = true;
          }
        }
      }
    }
    final shot = await step('screenshot', () => driver.screenshot());
    await File('$out/la-supervisor-panel.png').writeAsBytes(shot);
    stdout.writeln('populated=$hit screenshot: $out/la-supervisor-panel.png');
    exit(hit ? 0 : 4);
  } on Object catch (error) {
    stderr.writeln('probe failed: $error');
    exit(1);
  }
}
