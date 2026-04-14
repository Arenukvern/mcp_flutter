// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:test_app/agent_state.dart';
import 'package:test_app/live_edit_codex_fixture.dart';
import 'package:test_app/showcase_screen.dart';

final FlutterLiveEditAutoConfig _liveEditConfig =
    FlutterLiveEditAutoConfig.fromEnvironment(appId: 'test_app');

var _initialEntriesRegistered = false;
var _delayedEntriesRegistered = false;

Future<void> main({final bool enableDelayedMcpRegistration = true}) async {
  await bootstrapFlutterLiveEditApp(
    config: _liveEditConfig,
    registerInitialEntries: _registerInitialMCPTools,
    registerDelayedEntries: enableDelayedMcpRegistration
        ? _registerDelayedMCPTools
        : null,
    runApp: () => runApp(const MyApp()),
  );
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

  final fibonacciEntry = MCPCallEntry.tool(
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

  final appStateEntry = MCPCallEntry.resource(
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

  final agentStateEntry = MCPCallEntry.tool(
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

  await binding.addEntries(
    entries: {fibonacciEntry, appStateEntry, agentStateEntry},
  );
  print('Initial MCP tools and resources registered');
}

Future<void> _registerDelayedMCPTools() async {
  if (_delayedEntriesRegistered) return;
  _delayedEntriesRegistered = true;
  final binding = MCPToolkitBinding.instance;

  final preferencesEntry = MCPCallEntry.tool(
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(final BuildContext context) => MaterialApp(
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
    // FlutterLiveEditAutoHost reaches into `dart:io` (Directory.systemTemp) on
    // init, which throws UnsupportedOperation on web and leaves the whole app
    // subtree replaced by an error widget (breaking the showcase + semantics).
    // Skip it on web until live-edit grows a web-safe worktree service.
    home: kIsWeb
        ? _HomeRoute(testMode: _liveEditConfig.testMode)
        : FlutterLiveEditAutoHost(
            config: _liveEditConfig,
            child: _HomeRoute(testMode: _liveEditConfig.testMode),
          ),
  );
}

class _HomeRoute extends StatelessWidget {
  const _HomeRoute({required this.testMode});

  final bool testMode;

  @override
  Widget build(final BuildContext context) {
    if (!testMode) return const ShowcaseScreen();
    // Test mode: keep the codex fixture reachable above the showcase so
    // live-edit integration tests keep finding their fixed anchors.
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: const <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: LiveEditCodexFixture(),
          ),
          Expanded(child: ShowcaseScreen()),
        ],
      ),
    );
  }
}
