import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

/// Scroll the Automations pane into view, tap refresh, capture the pane.
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

  Future<List<Map<String, Object?>>> nodes() async {
    final tree = await step('snapshot', () => ext(ToolkitExtensions.snapshot));
    return (tree['nodes']! as List<Object?>)
        .whereType<Map<String, Object?>>()
        .toList();
  }

  Future<Map<String, Object?>?> visible(List<Map<String, Object?>> ns,
          {String label = 'notes-indexer'}) async =>
      ns.where((n) =>
          n['label'] == label &&
          (n['visibleInViewport'] == true)).firstOrNull;

  try {
    // 1) scroll until a row is actually on screen.
    var ns = await nodes();
    var row = await visible(ns);
    for (var i = 0; row == null && i < 6; i++) {
      await step('scroll-$i', () {
        return ext(ToolkitExtensions.scroll,
            args: {'direction': 'down', 'distance': 900});
      });
      await Future<void>.delayed(const Duration(milliseconds: 600));
      ns = await nodes();
      row = await visible(ns);
    }
    if (row == null) {
      stderr.writeln('notes-indexer row never became visible');
      exit(2);
    }
    final before = await step('shot-before', () => driver.screenshot());
    await File('$out/la-panel-before.png').writeAsBytes(before);

    // 2) tap refresh (button right of the header on the same row band).
    final header = ns
        .where((n) =>
            n['label'] == 'Automations' && n['visibleInViewport'] == true)
        .first;
    final hy = (header['center']! as Map<String, Object?>)['y']! as num;
    Map<String, Object?>? refresh;
    for (final n in ns) {
      if (n['type'] != 'button' || n['visibleInViewport'] != true) continue;
      final c = n['center']! as Map<String, Object?>;
      if (((c['y']! as num) - hy).abs() < 25 && (c['x']! as num) > 550) {
        refresh = n;
      }
    }
    if (refresh == null) {
      stderr.writeln('visible refresh button not found');
      exit(2);
    }
    stdout.writeln('tapping refresh ${refresh['ref']}');
    await step('tap-refresh', () {
      return ext(ToolkitExtensions.tap, args: {'ref': refresh!['ref']});
    });
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    // 3) re-scroll into view and capture.
    ns = await nodes();
    row = await visible(ns);
    for (var i = 0; row == null && i < 6; i++) {
      await step('re-scroll-$i', () {
        return ext(ToolkitExtensions.scroll,
            args: {'direction': 'down', 'distance': 900});
      });
      await Future<void>.delayed(const Duration(milliseconds: 600));
      ns = await nodes();
      row = await visible(ns);
    }
    final after = await step('shot-after', () => driver.screenshot());
    await File('$out/la-panel-after.png').writeAsBytes(after);

    // 4) report on-screen labels only.
    var stale = false;
    for (final n in ns) {
      if (n['visibleInViewport'] != true) continue;
      final label = '${n['label']}';
      if (label.contains('notes-indexer') ||
          label.contains('nightly-backup') ||
          label.contains('not a valid document') ||
          label.contains('No automations')) {
        stdout.writeln('onscreen: $label');
        if (label.contains('not a valid document') ||
            label.contains('No automations')) {
          stale = true;
        }
      }
    }
    stdout.writeln('stale markers on screen: $stale');
    exit(0);
  } on Object catch (error) {
    stderr.writeln('probe failed: $error');
    exit(1);
  }
}
