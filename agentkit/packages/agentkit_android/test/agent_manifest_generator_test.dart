import 'dart:convert';

import 'package:agentkit_android/agentkit_android.dart';
import 'package:agentkit_core/agentkit_core.dart';
import 'package:test/test.dart';

void main() {
  test('generateAndroidAgentManifest lists shortcuts', () {
    final json = generateAndroidAgentManifest([
      AgentIntentDescriptor(
        namespace: 'app',
        name: 'cart_total',
        description: 'cart',
        kind: AgentIntentKind.tool,
        inputSchema: const <String, Object?>{'type': 'object'},
      ),
    ]);

    final map = jsonDecode(json) as Map<String, Object?>;
    expect(map['platform'], 'android');
    expect(map['shortcuts']! as List, hasLength(1));
  });
}
