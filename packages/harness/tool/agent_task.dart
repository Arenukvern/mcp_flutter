import 'dart:io';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

/// Fills the editor sheet with an agent task and saves it.
Future<void> main(final List<String> args) async {
  final vmUri = Platform.environment['LA_VM_URI']!;
  final client = await VmClient.connect(Uri.parse(vmUri));
  final driver = ToolkitDriver(client);
  Future<T> step<T>(final String name, final Future<T> Function() body) =>
      body().timeout(const Duration(seconds: 25), onTimeout: () {
        stderr.writeln('TIMEOUT at step: $name');
        exit(3);
      });
  Future<Map<String, dynamic>> ext(final String name,
          {final Map<String, Object?> args = const {}}) =>
      step(name, () => client.callExtension(name, args: args));

  Future<List<Map<String, Object?>>> nodes() async {
    final tree = await step('snapshot', () => ext(ToolkitExtensions.snapshot));
    return (tree['nodes']! as List<Object?>)
        .whereType<Map<String, Object?>>()
        .toList();
  }

  Future<void> tapLabel(final String label) async {
    final node = (await nodes())
        .where((n) => '${n['label']}' == label)
        .firstOrNull;
    if (node == null) {
      stderr.writeln('$label not found');
      exit(2);
    }
    await step('tap-$label', () {
      return ext(ToolkitExtensions.tap, args: {'ref': node['ref']});
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Future<void> typeLabel(final String label, final String text) async {
    final field = (await nodes())
        .where((n) =>
            '${n['type']}'.toLowerCase().contains('textfield') &&
            '${n['label']}' == label)
        .firstOrNull;
    if (field == null) {
      stderr.writeln('field $label not found');
      exit(2);
    }
    await step('type-$label', () {
      return ext(ToolkitExtensions.enterText,
          args: {'ref': field['ref'], 'text': text});
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  try {
    await typeLabel('Name', 'nightly-agent');
    await tapLabel('Agent task');
    await tapLabel('Repeating');
    // The anchor time field (unlabeled, under the "at" row).
    final ns = await nodes();
    final atRow =
        ns.where((n) => '${n['label']}' == 'at').firstOrNull;
    final atY = atRow == null
        ? 0.0
        : ((atRow['center']! as Map<String, Object?>)['y']! as num);
    final atField = ns
        .where((n) =>
            '${n['type']}'.toLowerCase().contains('textfield') &&
            ('${n['label']}' == 'null' || '${n['label']}'.isEmpty) &&
            ((((n['center']! as Map<String, Object?>)['y']! as num) - atY)
                    .abs() <
                40))
        .firstOrNull;
    if (atField == null) {
      stderr.writeln('at field not found');
      exit(2);
    }
    await step('type-at', () {
      return ext(ToolkitExtensions.enterText,
          args: {'ref': atField['ref'], 'text': '03:00'});
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await typeLabel('Instructions',
        'Review today notes and suggest three tags for each untitled note.');
    final save = (await nodes())
        .where((n) => '${n['label']}' == 'Save')
        .firstOrNull;
    if (save == null) {
      stderr.writeln('Save not found');
      exit(2);
    }
    final bytes = await step('shot', () => driver.screenshot());
    await File('/tmp/la-agent-form.png').writeAsBytes(bytes);
    await step('tap-save', () {
      return ext(ToolkitExtensions.tap, args: {'ref': save['ref']});
    });
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final after = await nodes();
    final row = after
        .where((n) => '${n['label']}'.contains('nightly-agent'))
        .map((n) => '${n['label']}')
        .toList();
    stdout.writeln('row: $row');
    final bytes2 = await step('shot2', () => driver.screenshot());
    await File('/tmp/la-agent-row.png').writeAsBytes(bytes2);
    exit(0);
  } on Object catch (error) {
    stderr.writeln('probe failed: $error');
    exit(1);
  }
}
