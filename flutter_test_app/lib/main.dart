// ignore_for_file: avoid_print

import 'dart:async';

import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:intentcall_platform/intentcall_platform_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:test_app/agent_dogfood_entries.dart';
import 'package:test_app/agent_web_mcp_dogfood.dart';
import 'package:test_app/agent_state.dart';
import 'package:test_app/platform_view_showcase.dart';
import 'package:test_app/showcase_screen.dart';
import 'package:test_app/visual_reconstruct_screen.dart';

var _initialEntriesRegistered = false;
var _delayedEntriesRegistered = false;
final _intentCallProofRegistry = InMemoryAgentRegistry();
late final IntentCallFlutterHost _intentCallHost;
const _intentCallProtocolScheme = 'mcpfluttertest';

/// Registered on [MCPToolkitBinding.instance] for `navigate` / `handle_dialog`.
final GlobalKey<NavigatorState> showcaseNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main({final bool enableDelayedMcpRegistration = true}) async {
  WidgetsFlutterBinding.ensureInitialized();
  registerShowcasePlatformView();
  MCPToolkitBinding.instance
    ..initialize()
    ..initializeFlutterToolkit()
    ..navigatorKey = showcaseNavigatorKey;

  await _registerInitialMCPTools();
  unawaited(_intentCallHost.start());
  if (enableDelayedMcpRegistration) {
    // Mirror the previous bootstrap timing: a brief delay so a remote
    // observer can witness the dynamic-registry update event.
    Future.delayed(const Duration(seconds: 2), _registerDelayedMCPTools);
  }

  runApp(const MyApp());
}

// ---- MCP tool registrations (kept from previous demo) ------------------------

int _calculateFibonacci(final int n) {
  if (n <= 1) return n;
  var a = 0;
  var b = 1;
  for (var i = 2; i <= n; i++) {
    final temp = a + b;
    a = b;
    b = temp;
  }
  return b;
}

Map<String, dynamic> _getUserPreferences(final String category) {
  final allPreferences = <String, Map<String, Object>>{
    'theme': <String, Object>{'mode': 'dark', 'primaryColor': 'deepPurple'},
    'notifications': <String, Object>{'enabled': true, 'sound': true},
    'privacy': <String, Object>{'analytics': false, 'crashReporting': true},
  };
  if (category == 'all') return allPreferences;
  return <String, dynamic>{
    category: allPreferences[category] ?? <String, Object>{},
  };
}

AgentCallEntry _intentCallBridgePingEntry() => AgentCallEntry.tool(
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

AgentCallEntry _setGreetingEntry() => AgentCallEntry.tool(
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

AgentCallEntry _enableSwitchEntry() => AgentCallEntry.tool(
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

AgentEntityTypeDescriptor _showcaseScreenEntityType() =>
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

Future<void> _seedIntentCallShowcaseEntities() async {
  if (kIsWeb) return;
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
      deepLink: '$_intentCallProtocolScheme://entity/app_screen/greeting_form',
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
      deepLink: '$_intentCallProtocolScheme://entity/app_screen/feature_switch',
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
      deepLink: '$_intentCallProtocolScheme://entity/app_screen/counter_demo',
      properties: const <String, Object?>{
        'title': 'Counter Demo',
        'summary': 'Inspect the reactive counter fixture',
        'tags': <String>['counter', 'demo', 'runtime', 'spotlight'],
      },
    ),
  ];
  try {
    final count = await IntentCallPlatformEntityIndex().upsertAgentSnapshots(
      snapshots: snapshots,
    );
    debugPrint('intentcall seeded $count showcase entity snapshots');
  } catch (error, stackTrace) {
    debugPrint('intentcall entity snapshot seed failed: $error');
    debugPrint('$stackTrace');
  }
}

Future<void> _registerInitialMCPTools() async {
  if (_initialEntriesRegistered) return;
  _initialEntriesRegistered = true;
  final binding = MCPToolkitBinding.instance;
  final intentCallBridgePingEntry = _intentCallBridgePingEntry();
  final setGreetingEntry = _setGreetingEntry();
  final enableSwitchEntry = _enableSwitchEntry();

  final fibonacciEntry = mcpToolkitTool(
    namespace: 'app',
    handler: (final request) {
      final n = int.tryParse(request['n'] ?? '0') ?? 0;
      return MCPCallResult(
        message: 'Calculated Fibonacci number for position $n',
        parameters: {'result': _calculateFibonacci(n), 'position': n},
      );
    },
    definition: MCPToolDefinition(
      name: 'calculate_fibonacci',
      description: 'Calculate the nth Fibonacci number',
      inputSchema: ObjectSchema(
        properties: {
          'n': IntegerSchema(
            description: 'The position in the Fibonacci sequence',
            minimum: 0,
            maximum: 100,
          ),
        },
        required: ['n'],
      ),
    ),
  );

  final appStateEntry = mcpToolkitResource(
    namespace: 'app',
    definition: MCPResourceDefinition(
      name: 'app_state',
      description: 'Current agent-facing showcase state',
      mimeType: 'application/json',
    ),
    handler: (final request) => MCPCallResult(
      message: 'Agent showcase state',
      parameters: AgentState.instance.snapshot(),
    ),
  );

  final agentStateEntry = mcpToolkitTool(
    namespace: 'app',
    handler: (final request) => MCPCallResult(
      message: 'Agent showcase state',
      parameters: AgentState.instance.snapshot(),
    ),
    definition: MCPToolDefinition(
      name: 'get_agent_showcase_state',
      description:
          'Get the showcase app state: counter, greeting, toggle, slider.',
      inputSchema: ObjectSchema(properties: {}),
    ),
  );

  final dogfoodEntries = buildAgentDogfoodEntries();
  _intentCallProofRegistry.register(intentCallBridgePingEntry.toRegistration());
  _intentCallProofRegistry
    ..register(setGreetingEntry.toRegistration())
    ..register(enableSwitchEntry.toRegistration())
    ..registerEntityType(_showcaseScreenEntityType());
  _intentCallHost = IntentCallFlutterHost.bindRegistry(
    registry: _intentCallProofRegistry,
    policy: const IntentCallAuthorizationPolicy(
      allowedSources: <String>{
        IntentCallInvocationSource.webMcpDart,
        IntentCallInvocationSource.nativeGenerated,
        IntentCallInvocationSource.deepLink,
      },
      allowedQualifiedNames: <String>{
        'app_intentcall_bridge_ping',
        'app_set_greeting',
        'app_enable_switch',
      },
    ),
    registerWebMcp: kIsWeb,
    listenForDeepLinks: !kIsWeb,
    protocolScheme: _intentCallProtocolScheme,
    onEnvelope: (final envelope) {
      debugPrint('intentcall invoke: ${envelope.qualifiedName}');
    },
    onResult: (final envelope, final result) {
      if (envelope.source == IntentCallInvocationSource.nativeGenerated) {
        debugPrint(
          'intentcall pending invocation ${envelope.qualifiedName}: ${result.ok}',
        );
      } else {
        debugPrint(
          'intentcall ${envelope.source} invocation ${envelope.qualifiedName}: ${result.ok}',
        );
      }
    },
    onDenied: (final envelope, final result) {
      debugPrint(
        'intentcall denied ${envelope.source} invocation ${envelope.qualifiedName}: ${result.code}',
      );
    },
    onError: (final envelope, final error, final stackTrace) {
      debugPrint(
        'intentcall error ${envelope.source} invocation ${envelope.qualifiedName}: $error',
      );
    },
  );
  await binding.addEntries(
    entries: {
      fibonacciEntry,
      appStateEntry,
      agentStateEntry,
      intentCallBridgePingEntry,
      setGreetingEntry,
      enableSwitchEntry,
      ...dogfoodEntries,
    },
  );
  await _seedIntentCallShowcaseEntities();
  if (kIsWeb) {
    await wireWebMcpPublishAdapterDogfood(dogfoodEntries);
  }
  print('Initial MCP tools and resources registered');
}

Future<void> _registerDelayedMCPTools() async {
  if (_delayedEntriesRegistered) return;
  _delayedEntriesRegistered = true;
  final binding = MCPToolkitBinding.instance;

  final preferencesEntry = mcpToolkitTool(
    namespace: 'app',
    handler: (final request) {
      final category = request['category'] ?? 'all';
      return MCPCallResult(
        message: 'User preferences for category: $category',
        parameters: {
          'preferences': _getUserPreferences(category),
          'category': category,
        },
      );
    },
    definition: MCPToolDefinition(
      name: 'get_user_preferences',
      description: 'Get user preferences and settings',
      inputSchema: ObjectSchema(
        properties: {
          'category': Schema.string(
            description:
                'Preference category (theme, notifications, privacy, all)',
          ),
        },
      ),
    ),
  );

  await binding.addEntries(entries: {preferencesEntry});
  print('Delayed MCP tools registered - demonstrating auto-registration');
}

// ---- App ---------------------------------------------------------------------

/// When true (e.g. `--dart-define=DOGFOOD_VISUAL=true`), boot on the visual
/// reconstruct fixture for warm-path guild compare without HS navigation.
const _dogfoodVisual = bool.fromEnvironment('DOGFOOD_VISUAL');

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(final BuildContext context) => MaterialApp(
    navigatorKey: showcaseNavigatorKey,
    title: 'MCP Flutter',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF007AFF),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    ),
    routes: {
      '/': (_) => const ShowcaseScreen(),
      '/visual-reconstruct': (_) => const VisualReconstructScreen(),
    },
    initialRoute: _dogfoodVisual ? '/visual-reconstruct' : '/',
  );
}
