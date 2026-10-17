import 'dart:io';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

Future<void> main() async {
  final client = await VmClient.connect(Uri.parse(Platform.environment['LA_VM_URI']!));
  final driver = ToolkitDriver(client);
  Future<List<Map<String, Object?>>> nodes() async {
    final tree = await client
        .callExtension(ToolkitExtensions.snapshot, args: const {})
        .timeout(const Duration(seconds: 25));
    return (tree['nodes']! as List<Object?>)
        .whereType<Map<String, Object?>>()
        .toList();
  }
  Future<void> typeUnlabeled(String hint, String text) async {
    final field = (await nodes())
        .where((n) =>
            '${n['type']}'.toLowerCase().contains('textfield') &&
            '${n['label']}'.contains(hint))
        .firstOrNull;
    if (field == null) {
      stderr.writeln('field with hint "$hint" not found');
      exit(2);
    }
    await client.callExtension(ToolkitExtensions.enterText,
        args: {'ref': field['ref'], 'text': text}).timeout(const Duration(seconds: 25));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  // Name: the labeled field.
  final name = (await nodes())
      .where((n) =>
          '${n['type']}'.toLowerCase().contains('textfield') &&
          '${n['label']}' == 'Name')
      .firstOrNull;
  if (name == null) { stderr.writeln('Name not found'); exit(2); }
  await client.callExtension(ToolkitExtensions.enterText,
      args: {'ref': name['ref'], 'text': 'nightly-agent'}).timeout(const Duration(seconds: 25));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  // Anchor: hint 03:00.
  await typeUnlabeled('03:00', '03:00');
  // Instructions.
  await typeUnlabeled('Instructions', 'Review today notes and suggest three tags for each untitled note.');
  final save = (await nodes())
      .where((n) => '${n['label']}' == 'Save')
      .firstOrNull;
  if (save == null) { stderr.writeln('Save not found'); exit(2); }
  final shot = await driver.screenshot().timeout(const Duration(seconds: 25));
  await File('/tmp/la-agent-form.png').writeAsBytes(shot);
  await client.callExtension(ToolkitExtensions.tap, args: {'ref': save['ref']})
      .timeout(const Duration(seconds: 25));
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  final rows = (await nodes())
      .where((n) => '${n['label']}'.contains('nightly-agent'))
      .map((n) => '${n['label']}')
      .toList();
  stdout.writeln('row: $rows');
  final shot2 = await driver.screenshot().timeout(const Duration(seconds: 25));
  await File('/tmp/la-agent-row.png').writeAsBytes(shot2);
  exit(0);
}
