import 'dart:convert';
import 'dart:io';

void main() {
  final f = File('/Users/anton/mcp/mcp_flutter/flutter_test_app/lib/main.dart');
  final content = f.readAsStringSync();
  final newContent = content.replaceFirst("'About This Demo'", "'Hello Live Flutter Editing'");
  const patch = r'''--- a/lib/main.dart
+++ b/lib/main.dart
@@ -767,7 +767,7 @@
                 Semantics(
                   identifier: 'about_demo_heading',
                   child: Text(
-                    'About This Demo',
+                    'Hello Live Flutter Editing',
                     style: Theme.of(context).textTheme.titleLarge,
                   ),
                 ),''';
  final proposal = <String, Object>{
    'proposalId': 'live_edit_1773431517345_cursor_agent',
    'backendId': 'cursor_agent',
    'summary': 'Update about-demo heading text to "Hello Live Flutter Editing" in lib/main.dart.',
    'patch': patch,
    'changedFiles': <String>['lib/main.dart'],
    'filePatches': <Map<String, String>>[
      <String, String>{'path': 'lib/main.dart', 'content': newContent, 'patch': patch}
    ],
    'expectedRuntimeEffects': <String>['Header section heading displays "Hello Live Flutter Editing".'],
    'validationSteps': <String>['Hot reload or restart app and confirm heading text in header card.'],
    'warnings': <String>[],
    'riskFlags': <String>[],
  };
  File('/Users/anton/mcp/mcp_flutter/flutter_test_app/resolution_output.json').writeAsStringSync(JsonEncoder.withIndent('  ').convert(proposal));
}
