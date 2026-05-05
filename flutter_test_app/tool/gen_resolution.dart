import 'dart:convert';
import 'dart:io';

void main() {
  final f = File('/Users/anton/mcp/mcp_flutter/flutter_test_app/lib/main.dart');
  final content = f.readAsStringSync();
  final newContent = content.replaceFirst(
    "'Hello Live Flutter Editing'",
    "'Hello Flutter MCP Demo'",
  );
  const patch = r'''--- a/lib/main.dart
+++ b/lib/main.dart
@@ -781,7 +781,7 @@
                 Semantics(
                   identifier: 'about_demo_heading',
                   child: Text(
-                    'Hello Live Flutter Editing',
+                    'Hello Flutter MCP Demo',
                     style: Theme.of(context).textTheme.titleLarge,
                   ),
                 ),''';
  final proposal = <String, Object>{
    'proposalId': 'live_edit_1773440023273-cursor_agent',
    'backendId': 'cursor_agent',
    'summary': "Update about-demo heading text to 'Hello Flutter MCP Demo'.",
    'patch': patch,
    'changedFiles': <String>['lib/main.dart'],
    'filePatches': <Map<String, String>>[
      <String, String>{
        'path': 'lib/main.dart',
        'content': newContent,
        'patch': patch,
      },
    ],
    'expectedRuntimeEffects': <String>[
      'Header section heading displays "Hello Flutter MCP Demo".',
    ],
    'validationSteps': <String>[
      'Hot reload or restart app and confirm heading text in header card.',
    ],
    'warnings': <String>[],
    'riskFlags': <String>[],
  };
  File(
    '/Users/anton/mcp/mcp_flutter/flutter_test_app/resolution_output.json',
  ).writeAsStringSync(JsonEncoder.withIndent('  ').convert(proposal));
}
