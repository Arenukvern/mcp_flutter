// ignore_for_file: avoid_print

import 'dart:async';

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
  if (!kIsWeb) {
    unawaited(
      IntentCallInvokeLinkListener(
        onQualifiedName: (final name) {
          debugPrint('intentcall invoke: $name');
        },
      ).start(),
    );
  }
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

Future<void> _registerInitialMCPTools() async {
  if (_initialEntriesRegistered) return;
  _initialEntriesRegistered = true;
  final binding = MCPToolkitBinding.instance;

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
  await binding.addEntries(
    entries: {
      fibonacciEntry,
      appStateEntry,
      agentStateEntry,
      ...dogfoodEntries,
    },
  );
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
