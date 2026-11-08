import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

/// Visual acceptance for the on-device automations pane (ADR-0041 §6).
/// Every step is hard-timeboxed: a stuck step fails the run instead of
/// hanging it.
Future<void> main(List<String> args) async {
  final out = args.isNotEmpty ? args.first : '/tmp';
  final vmUri = Platform.environment['LA_VM_URI'] ??
      'http://127.0.0.1:57684/${Platform.environment['LA_VM_TOKEN'] ?? ''}/';
  final client = await VmClient.connect(Uri.parse(vmUri));
  final driver = ToolkitDriver(client);
  var stepTimeout = const Duration(seconds: 25);
  Future<T> step<T>(String name, Future<T> Function() body) =>
      body().timeout(stepTimeout, onTimeout: () {
        stderr.writeln('TIMEOUT at step: $name');
        exit(3);
      });
  Future<Map<String, dynamic>> ext(
    String name, {
    Map<String, Object?> args = const <String, Object?>{},
  }) =>
      step(name, () => client.callExtension(name, args: args));
  Future<Map<String, dynamic>> snapshot() => ext(ToolkitExtensions.snapshot);

  try {
    // Fresh snapshot -> fresh gear ref (4th top-rail button) -> tap.
    final tree = await snapshot();
    final buttons = (tree['nodes']! as List<Object?>)
        .whereType<Map<String, Object?>>()
        .where((n) => n['type'] == 'button')
        .toList();
    final gear = buttons.length > 3 ? buttons[3] : buttons.last;
    final gearRef = gear['ref']! as String;
    await step('tap-gear',
        () => ext(ToolkitExtensions.tap, args: {'ref': gearRef}));
    final shotSettings = await step('screenshot', () => driver.screenshot());
    await File('$out/la-settings.png').writeAsBytes(shotSettings);
    stdout.writeln('settings screenshot: $out/la-settings.png');

    // Scroll the storage list until the automations panel is named.
    var visible = false;
    String panel = '';
    for (var attempt = 0; attempt < 6 && !visible; attempt++) {
      panel = const JsonEncoder.withIndent(' ').convert(await snapshot());
      visible =
          panel.contains('notes-indexer') || panel.contains('Automations');
      if (!visible) {
        await step('scroll-$attempt', () {
          stepTimeout = const Duration(seconds: 15);
          return ext(
            ToolkitExtensions.scroll,
            args: {'direction': 'down', 'scrollAmount': 3},
          );
        });
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }
    await File('$out/la-supervisor-semantic.json').writeAsString(panel);
    stdout.writeln('automations visible in semantics: $visible');
    final shotPanel = await step('screenshot-panel', () => driver.screenshot());
    await File('$out/la-supervisor-panel.png').writeAsBytes(shotPanel);
    stdout.writeln('panel screenshot: $out/la-supervisor-panel.png');
    for (final line in panel.split('\n')) {
      if (line.contains('Automations') ||
          line.contains('notes-indexer') ||
          line.contains('nightly-backup')) {
        stdout.writeln('panel: ${line.trim()}');
      }
    }
    exit(0);
  } on Object catch (error) {
    stderr.writeln('probe failed: $error');
    exit(1);
  }
}
