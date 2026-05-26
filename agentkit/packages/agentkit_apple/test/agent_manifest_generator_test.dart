import 'dart:convert';

import 'package:agentkit_apple/agentkit_apple.dart';
import 'package:agentkit_core/agentkit_core.dart';
import 'package:test/test.dart';

void main() {
  test('generateAppleAgentManifest includes tool and resource intents', () {
    final json = generateAppleAgentManifest([
      AgentIntentDescriptor(
        namespace: 'fmt',
        name: 'wait_for',
        description: 'wait',
        kind: AgentIntentKind.tool,
        inputSchema: const <String, Object?>{'type': 'object'},
      ),
      AgentIntentDescriptor(
        namespace: 'app',
        name: 'diagnostics',
        description: 'diag',
        kind: AgentIntentKind.resource,
        inputSchema: const <String, Object?>{'type': 'object'},
        mimeType: 'application/json',
      ),
    ]);

    final map = jsonDecode(json) as Map<String, Object?>;
    expect(map['platform'], 'apple');
    final intents = map['intents']! as List;
    expect(intents, hasLength(2));
    expect((intents[1] as Map)['resourceUri'], isNotNull);
  });
}
