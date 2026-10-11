import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

/// Close Settings (X) and reopen it, so the Automations pane re-mounts
/// and re-reads the store — the interface-level reload.
Future<void> main(final List<String> args) async {
  final out = args.isNotEmpty ? args.first : '/tmp';
  final vmUri = Platform.environment['LA_VM_URI']!;
  final client = await VmClient.connect(Uri.parse(vmUri));
  final driver = ToolkitDriver(client);
  Future<T> step<T>(final String name, final Future<T> Function() body) =>
      body().timeout(const Duration(seconds: 25), onTimeout: () {
        stderr.writeln('TIMEOUT at step: $name');
        exit(3);
      });
  Future<Map<String, dynamic>> ext(
    final String name, {
    final Map<String, Object?> args = const <String, Object?>{},
  }) =>
      step(name, () => client.callExtension(name, args: args));

  Future<List<Map<String, Object?>>> nodes() async {
    final tree = await step('snapshot', () => ext(ToolkitExtensions.snapshot));
    return (tree['nodes']! as List<Object?>)
        .whereType<Map<String, Object?>>()
        .toList();
  }

  Future<void> scrollToRow() async {
    var ns = await nodes();
    var row = ns
        .where((n) => n['label'] == 'notes-indexer' && n['visibleInViewport'] == true)
        .firstOrNull;
    for (var i = 0; row == null && i < 6; i++) {
      await step('scroll-$i', () {
        return ext(ToolkitExtensions.scroll,
            args: {'direction': 'down', 'distance': 900});
      });
      await Future<void>.delayed(const Duration(milliseconds: 600));
      ns = await nodes();
      row = ns
          .where((n) =>
              n['label'] == 'notes-indexer' &&
              n['visibleInViewport'] == true)
          .firstOrNull;
    }
    if (row == null) {
      stderr.writeln('notes-indexer row never became visible');
      exit(2);
    }
  }

  try {
    // 1) scroll to top, then tap the X close (first visible button).
    await step('scroll-top', () {
      return ext(ToolkitExtensions.scroll,
          args: {'direction': 'up', 'distance': 4000});
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    var ns = await nodes();
    final closeButtons = ns
        .where((n) =>
            n['type'] == 'button' &&
            n['visibleInViewport'] == true &&
            (((n['center']! as Map<String, Object?>)['y']! as num) < 60))
        .toList()
      ..sort((a, b) => ((a['center']! as Map<String, Object?>)['x']! as num)
          .compareTo((b['center']! as Map<String, Object?>)['x']! as num));
    if (closeButtons.isEmpty) {
      stderr.writeln('no close button at top');
      exit(2);
    }
    stdout.writeln('tapping close ${closeButtons.first['ref']}');
    await step('tap-close', () {
      return ext(ToolkitExtensions.tap,
          args: {'ref': closeButtons.first['ref']});
    });
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    // 2) reopen Settings via the 4th top-rail button.
    ns = await nodes();
    final rail = ns
        .where((n) =>
            n['type'] == 'button' &&
            n['visibleInViewport'] == true &&
            (((n['center']! as Map<String, Object?>)['y']! as num) < 60))
        .toList()
      ..sort((a, b) => ((a['center']! as Map<String, Object?>)['x']! as num)
          .compareTo((b['center']! as Map<String, Object?>)['x']! as num));
    if (rail.length < 4) {
      stderr.writeln('top rail has ${rail.length} buttons');
      exit(2);
    }
    stdout.writeln('tapping gear ${rail[3]['ref']}');
    await step('tap-gear', () {
      return ext(
          ToolkitExtensions.tap, args: {'ref': rail[3]['ref']});
    });
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    // 3) scroll the pane into view and capture.
    await scrollToRow();
    final shot = await step('shot', () => driver.screenshot());
    await File('$out/la-panel-remounted.png').writeAsBytes(shot);
    ns = await nodes();
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
    exit(stale ? 4 : 0);
  } on Object catch (error) {
    stderr.writeln('probe failed: $error');
    exit(1);
  }
}
