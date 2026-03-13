// One-off script to emit live-edit resolution JSON. Run from flutter_test_app: dart run tool/emit_resolution.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final path = 'lib/main.dart';
  final content = File(path).readAsStringSync();
  final filePatch = <String, dynamic>{
    'path': path,
    'content': content,
    'patch': '''--- a/lib/main.dart
+++ b/lib/main.dart
@@ -781,7 +781,7 @@
                 Semantics(
                   identifier: 'about_demo_heading',
                   child: Text(
-                    'Hello Live Flutter Editing',
+                    'Hello Flutter MCP Demo',
                     style: Theme.of(context).textTheme.titleLarge,
                   ),
                 ),''',
  };
  final proposal = <String, dynamic>{
    'proposalId': 'live_edit_1773440023273-cursor_agent',
    'backendId': 'cursor_agent',
    'summary': "Update about-demo heading text to 'Hello Flutter MCP Demo'.",
    'patch': 'lib/main.dart: replace Text data in Semantics(about_demo_heading) from "Hello Live Flutter Editing" to "Hello Flutter MCP Demo".',
    'changedFiles': <String>[path],
    'filePatches': <Map<String, dynamic>>[filePatch],
    'expectedRuntimeEffects': <String>[
      'Header section title shows "Hello Flutter MCP Demo" after hot reload or restart.',
    ],
    'validationSteps': <String>[
      'Run app and confirm header card shows the new title.',
    ],
    'warnings': <String>[],
    'riskFlags': <String>[],
  };
  final out = File('resolution_output.json');
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(proposal));
}
