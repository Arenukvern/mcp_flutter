// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_live_edit_property_edit/flutter_live_edit_property_edit.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:provider/provider.dart';
import 'package:test_app/change_notifier_example.dart';
import 'package:test_app/live_edit_codex_fixture.dart';
import 'package:test_app/stateful_widget_example.dart';

final FlutterLiveEditAutoConfig _liveEditConfig =
    FlutterLiveEditAutoConfig.fromEnvironment(appId: 'test_app');

Future<void> main() async {
  await bootstrapFlutterLiveEditApp(
    config: _liveEditConfig,
    registerInitialEntries: _registerInitialMCPTools,
    registerDelayedEntries: _registerDelayedMCPTools,
    runApp: () => runApp(const MyApp()),
  );
}

int _calculateFibonacci(final int n) {
  if (n <= 1) {
    return n;
  }
  int a = 0;
  int b = 1;
  for (int i = 2; i <= n; i++) {
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

  if (category == 'all') {
    return allPreferences;
  }

  return <String, dynamic>{
    category: allPreferences[category] ?? <String, Object>{},
  };
}

Future<void> _registerDelayedMCPTools() async {
  final binding = MCPToolkitBinding.instance;

  final preferencesEntry = MCPCallEntry.tool(
    handler: (final request) {
      final category = request['category'] ?? 'all';
      final preferences = _getUserPreferences(category);
      return MCPCallResult(
        message: 'User preferences for category: $category',
        parameters: {'preferences': preferences, 'category': category},
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

Future<void> _registerInitialMCPTools() async {
  final binding = MCPToolkitBinding.instance;
  await Future.delayed(const Duration(seconds: 1));

  final fibonacciEntry = MCPCallEntry.tool(
    handler: (final request) {
      final n = int.tryParse(request['n'] ?? '0') ?? 0;
      final result = _calculateFibonacci(n);
      return MCPCallResult(
        message: 'Calculated Fibonacci number for position $n',
        parameters: {'result': result, 'position': n},
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
      description: 'Current application state and configuration',
      mimeType: 'application/json',
    ),
    handler: (final request) {
      return MCPCallResult(
        message: 'Current application state and configuration',
        parameters: {
          'appName': 'MCP Toolkit Demo',
          'isConnected': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    },
  );

  await binding.addEntries(entries: {fibonacciEntry, appStateEntry});
  print('Initial MCP tools and resources registered');
}

class ErrorSection extends StatelessWidget {
  const ErrorSection({super.key});

  @override
  Widget build(final BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Error Section',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // @ai DO NOT FIX:
            // this line will cause an overflow error for testing purposes
            // so ai could find the cause using MCP screenshot tool
            // or get error tool.
            Row(
              children: List.generate(
                100,
                (final index) => const Text('hello world'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MCPDemoHomePage extends StatefulWidget {
  const MCPDemoHomePage({super.key});

  @override
  State<MCPDemoHomePage> createState() => _MCPDemoHomePageState();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _propertyPanelSectionBuilder = LiveEditPropertyEditPlugin.install();
  final _isPropertyPanelEnabled = false;

  @override
  Widget build(final BuildContext context) {
    return MaterialApp(
      title: 'MCP Toolkit Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: ChangeNotifierProvider(
        create: (final context) => CustomNotifier(),
        child: FlutterLiveEditAutoHost(
          config: _liveEditConfig,
          buildPropertyPanelSection: _isPropertyPanelEnabled
              ? _propertyPanelSectionBuilder
              : null,
          child: const MCPDemoHomePage(),
        ),
      ),
    );
  }
}

class _CounterDemoSection extends StatelessWidget {
  const _CounterDemoSection();

  @override
  Widget build(final BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Semantics(
                  identifier: 'counter_demo_icon',
                  child: Icon(
                    Icons.calculate,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  identifier: 'counter_demo_heading',
                  child: Text(
                    'State Management Examples',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: StatefulCounterWidget()),
                SizedBox(width: 16),
                Expanded(child: ChangeNotifierCounterWidget()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DynamicToolRegistration extends StatefulWidget {
  const _DynamicToolRegistration();

  @override
  State<_DynamicToolRegistration> createState() =>
      _DynamicToolRegistrationState();
}

class _DynamicToolRegistrationState extends State<_DynamicToolRegistration> {
  int _toolCount = 0;

  @override
  Widget build(final BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Register new MCP tools dynamically to demonstrate auto-registration capabilities.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Semantics(
              identifier: 'register_new_tool_button',
              button: true,
              child: ElevatedButton.icon(
                onPressed: _registerNewTool,
                icon: const Icon(Icons.add_circle),
                label: const Text(
                  'Register New Tool',
                  semanticsIdentifier: 'register_new_tool_label',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Semantics(
              container: true,
              identifier: 'dynamic_tool_count',
              label: 'Tools created: $_toolCount',
              liveRegion: true,
              child: ExcludeSemantics(
                child: Text(
                  'Tools created: $_toolCount',
                  semanticsIdentifier: 'dynamic_tool_count_text',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _registerNewTool() async {
    final binding = MCPToolkitBinding.instance;

    try {
      _toolCount++;
      final toolName = 'dynamic_tool_$_toolCount';

      final dynamicEntry = MCPCallEntry.tool(
        definition: MCPToolDefinition(
          name: toolName,
          description: 'Dynamically registered tool #$_toolCount',
          inputSchema: ObjectSchema(properties: {}),
        ),
        handler: (final request) {
          return MCPCallResult(
            message: 'Response from dynamically registered tool #$_toolCount',
            parameters: {
              'toolNumber': _toolCount,
              'registeredAt': DateTime.now().toIso8601String(),
            },
          );
        },
      );

      await binding.addEntries(entries: {dynamicEntry});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully registered tool: $toolName'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register tool: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(final BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Semantics(
                  identifier: 'about_demo_heading',
                  child: Text(
                    'Live Edit with AI agents for Flutter App',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'This Flutter app demonstrates dynamic MCP (Model Context Protocol) tool registration using MCP Toolkit. '
              'The app registers various tools and resources that can be accessed by MCP clients.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: const Text('MCP Integration'),
                  backgroundColor: Colors.blue.shade100,
                ),
                Chip(
                  label: const Text('Dynamic Registration'),
                  backgroundColor: Colors.green.shade100,
                ),
                Chip(
                  label: const Text('Flutter Toolkit'),
                  backgroundColor: Colors.purple.shade100,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MCPDemoHomePageState extends State<MCPDemoHomePage> {
  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text(
          'MCP Toolkit Demo',
          semanticsIdentifier: 'app_title_text',
        ),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_liveEditConfig.testMode) ...[
              const LiveEditCodexFixture(),
              const SizedBox(height: 24),
            ],
            const _HeaderSection(),
            const SizedBox(height: 24),
            const _CounterDemoSection(),
            const SizedBox(height: 24),
            const _MCPToolsSection(),
            const SizedBox(height: 24),
            const _StatusSection(),
            const SizedBox(height: 24),
            const ErrorSection(),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeMCPIntegration();
  }

  void _initializeMCPIntegration() {
    addMcpTool(
      MCPCallEntry.tool(
        handler: (final request) {
          return MCPCallResult(
            message: 'Current app UI state',
            parameters: {
              'totalMCPEntries': MCPToolkitBinding.instance.allEntries.length,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        },
        definition: MCPToolDefinition(
          name: 'get_app_ui_state',
          description: 'Get current UI state and MCP integration status',
          inputSchema: ObjectSchema(properties: {}),
        ),
      ),
    );
  }
}

class _MCPToolsSection extends StatelessWidget {
  const _MCPToolsSection();

  @override
  Widget build(final BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'MCP Tool Management',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _DynamicToolRegistration(),
          ],
        ),
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection();

  @override
  Widget build(final BuildContext context) {
    final allEntries = MCPToolkitBinding.instance.allEntries;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dashboard,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'MCP Status Dashboard',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  const Text(
                    'MCP Toolkit Active',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Registered Entries: ${allEntries.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (allEntries.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Service Extensions:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: allEntries
                          .map(
                            (final entry) => Chip(
                              label: Text(
                                entry.key,
                                style: const TextStyle(fontSize: 11),
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
