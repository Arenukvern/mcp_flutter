import 'package:flutter/foundation.dart';
import 'package:intentcall_platform/intentcall_platform_flutter.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:test_app/agent_state.dart';

const intentCallProtocolScheme = 'mcpfluttertest';

AgentCallEntry buildIntentCallBridgePingEntry() => AgentCallEntry.tool(
  namespace: 'app',
  name: 'intentcall_bridge_ping',
  description:
      'Proof that WebMCP/native bridge dispatch executes Dart registry logic.',
  inputSchema: const <String, Object?>{
    'type': 'object',
    'additionalProperties': false,
    'properties': <String, Object?>{
      'echo': <String, Object?>{
        'type': 'string',
        'description': 'Value echoed by Dart registry proof.',
      },
    },
    'required': <String>['echo'],
  },
  handler: (final args) async => AgentResult.success(
    message: 'intentcall bridge pong',
    data: <String, Object?>{
      'source': 'dart_registry',
      'kind': 'intentcall_bridge_ping',
      'echo': args['echo'],
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    },
  ),
);

AgentCallEntry buildSetGreetingEntry() => AgentCallEntry.tool(
  namespace: 'app',
  name: 'set_greeting',
  description: 'Fill the showcase greeting field with text.',
  inputSchema: const <String, Object?>{
    'type': 'object',
    'additionalProperties': false,
    'properties': <String, Object?>{
      'text': <String, Object?>{
        'type': 'string',
        'description': 'Text to place in the greeting field.',
      },
    },
    'required': <String>['text'],
  },
  handler: (final args) async {
    final text = '${args['text'] ?? ''}';
    AgentState.instance
      ..greeting = text
      ..logMessage('IntentCall set greeting: $text');
    return AgentResult.success(
      message: 'Greeting updated.',
      data: <String, Object?>{
        'kind': 'set_greeting',
        'greeting': AgentState.instance.greeting,
        'state': AgentState.instance.snapshot(),
      },
    );
  },
);

AgentCallEntry buildEnableSwitchEntry() => AgentCallEntry.tool(
  namespace: 'app',
  name: 'enable_switch',
  description: 'Enable the showcase feature switch.',
  inputSchema: const <String, Object?>{
    'type': 'object',
    'additionalProperties': false,
    'properties': <String, Object?>{},
  },
  handler: (final args) async {
    AgentState.instance
      ..toggle = true
      ..logMessage('IntentCall enabled showcase switch');
    return AgentResult.success(
      message: 'Switch enabled.',
      data: <String, Object?>{
        'kind': 'enable_switch',
        'toggle': AgentState.instance.toggle,
        'state': AgentState.instance.snapshot(),
      },
    );
  },
);

AgentEntityTypeDescriptor buildShowcaseScreenEntityType() =>
    AgentEntityTypeDescriptor(
      namespace: 'app',
      name: 'screen',
      identifierName: 'id',
      displayName: 'Showcase Screen',
      privacy: AgentEntityPrivacy.public,
      deepLinkBehavior: AgentEntityDeepLinkBehavior.optional,
      openBehavior: AgentEntityOpenBehavior.supported,
      properties: <AgentEntityPropertyDescriptor>[
        AgentEntityPropertyDescriptor(
          name: 'title',
          valueType: AgentEntityPropertyValueType.string,
          isDisplay: true,
          isSearchable: true,
          isIndexed: true,
          privacy: AgentEntityPrivacy.public,
        ),
        AgentEntityPropertyDescriptor(
          name: 'summary',
          valueType: AgentEntityPropertyValueType.string,
          isDisplay: true,
          isSearchable: true,
          isIndexed: true,
          privacy: AgentEntityPrivacy.public,
        ),
        AgentEntityPropertyDescriptor(
          name: 'tags',
          valueType: AgentEntityPropertyValueType.array,
          isSearchable: true,
          isIndexed: true,
          privacy: AgentEntityPrivacy.public,
        ),
      ],
    );

Future<void> seedIntentCallShowcaseEntities() async {
  final snapshots = <AgentEntitySnapshot>[
    AgentEntitySnapshot(
      ref: const AgentEntityRef(
        namespace: 'app',
        typeName: 'screen',
        identifier: 'greeting_form',
      ),
      title: 'Greeting Form',
      subtitle: 'Fill the showcase greeting text field',
      keywords: const <String>['form', 'text', 'greeting', 'siri'],
      deepLink: '$intentCallProtocolScheme://entity/app_screen/greeting_form',
      properties: const <String, Object?>{
        'title': 'Greeting Form',
        'summary': 'Fill the showcase greeting text field',
        'tags': <String>['form', 'text', 'greeting', 'siri'],
      },
    ),
    AgentEntitySnapshot(
      ref: const AgentEntityRef(
        namespace: 'app',
        typeName: 'screen',
        identifier: 'feature_switch',
      ),
      title: 'Feature Switch',
      subtitle: 'Enable the showcase switch from an Apple action',
      keywords: const <String>['toggle', 'switch', 'shortcut', 'siri'],
      deepLink: '$intentCallProtocolScheme://entity/app_screen/feature_switch',
      properties: const <String, Object?>{
        'title': 'Feature Switch',
        'summary': 'Enable the showcase switch from an Apple action',
        'tags': <String>['toggle', 'switch', 'shortcut', 'siri'],
      },
    ),
    AgentEntitySnapshot(
      ref: const AgentEntityRef(
        namespace: 'app',
        typeName: 'screen',
        identifier: 'counter_demo',
      ),
      title: 'Counter Demo',
      subtitle: 'Inspect the reactive counter fixture',
      keywords: const <String>['counter', 'demo', 'runtime', 'spotlight'],
      deepLink: '$intentCallProtocolScheme://entity/app_screen/counter_demo',
      properties: const <String, Object?>{
        'title': 'Counter Demo',
        'summary': 'Inspect the reactive counter fixture',
        'tags': <String>['counter', 'demo', 'runtime', 'spotlight'],
      },
    ),
  ];
  final descriptor = buildShowcaseScreenEntityType();
  final count = await IntentCallPlatformEntityIndex().upsertAgentSnapshotsForType(
    descriptor: descriptor,
    snapshots: snapshots,
  );
  debugPrint('intentcall seeded $count showcase entity snapshots');
}
