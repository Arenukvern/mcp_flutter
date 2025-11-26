// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:provider/provider.dart';
import 'package:test_app/change_notifier_example.dart';
import 'package:test_app/stateful_widget_example.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      
      if (kIsWeb) {
        await MCPToolkitBinding.instance.initializeWebBridgeForWeb(
          bridgeUrl: 'ws://localhost:8183',
        );
        MCPToolkitBinding.instance.initializeFlutterToolkit();
      } else {
        MCPToolkitBinding.instance
          ..initialize()
          ..initializeFlutterToolkit();
      }

      await _registerInitialMCPTools();
      runApp(const MyApp());

      Timer(const Duration(seconds: 5), () async {
        await _registerDelayedMCPTools();
      });
    },
    (error, stack) {
      MCPToolkitBinding.instance.handleZoneError(error, stack);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCP Toolkit Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: ChangeNotifierProvider(
        create: (context) => CustomNotifier(),
        child: const MCPDemoHomePage(),
      ),
    );
  }
}

class MCPDemoHomePage extends StatefulWidget {
  const MCPDemoHomePage({super.key});

  @override
  State<MCPDemoHomePage> createState() => _MCPDemoHomePageState();
}

class _MCPDemoHomePageState extends State<MCPDemoHomePage> {
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _initializeMCPIntegration();
    _startPeriodicStatusCheck();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _initializeMCPIntegration() {
    // Register a tool that tracks UI state
    addMcpTool(
      MCPCallEntry.tool(
        handler: (request) {
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

  void _startPeriodicStatusCheck() {
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('MCP Toolkit Demo'),
        elevation: 2,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            _HeaderSection(),
            SizedBox(height: 24),

            // Counter Demos Section
            _CounterDemoSection(),
            SizedBox(height: 24),

            // MCP Tools Section
            _MCPToolsSection(),
            SizedBox(height: 24),

            // Status Section
            _StatusSection(),
            SizedBox(height: 24),

            // Error Section
            ErrorSection(),
          ],
        ),
      ),
    );
  }
}

// Header section explaining the demo
class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                Text(
                  'About This Demo',
                  style: Theme.of(context).textTheme.titleLarge,
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

// Counter demonstrations section
class _CounterDemoSection extends StatelessWidget {
  const _CounterDemoSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calculate,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'State Management Examples',
                  style: Theme.of(context).textTheme.titleLarge,
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

class ErrorSection extends StatelessWidget {
  const ErrorSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red),
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
            Row(children: List.generate(100, (index) => Text('hello world'))),
          ],
        ),
      ),
    );
  }
}

// MCP Tools management section
class _MCPToolsSection extends StatelessWidget {
  const _MCPToolsSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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

// Dynamic tool registration widget
class _DynamicToolRegistration extends StatefulWidget {
  const _DynamicToolRegistration();

  @override
  State<_DynamicToolRegistration> createState() =>
      _DynamicToolRegistrationState();
}

class _DynamicToolRegistrationState extends State<_DynamicToolRegistration> {
  int _toolCount = 0;

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
        handler: (request) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register tool: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            ElevatedButton.icon(
              onPressed: _registerNewTool,
              icon: const Icon(Icons.add_circle),
              label: const Text('Register New Tool'),
            ),
            const SizedBox(width: 16),
            Text(
              'Tools created: $_toolCount',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}

// Status and information section
class _StatusSection extends StatelessWidget {
  const _StatusSection();

  @override
  Widget build(BuildContext context) {
    final allEntries = MCPToolkitBinding.instance.allEntries;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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

            // Connection Status
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

            // Registered Entries
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
                    // Fixed the overflow issue by using proper wrapping
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children:
                          allEntries
                              .map(
                                (entry) => Chip(
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

// MCP Tool Registration Functions
Future<void> _registerInitialMCPTools() async {
  final binding = MCPToolkitBinding.instance;
  await Future.delayed(const Duration(seconds: 1));

  final fibonacciEntry = MCPCallEntry.tool(
    handler: (request) {
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
    handler: (request) {
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

Future<void> _registerDelayedMCPTools() async {
  final binding = MCPToolkitBinding.instance;

  final preferencesEntry = MCPCallEntry.tool(
    handler: (request) {
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

// Helper Functions
int _calculateFibonacci(int n) {
  if (n <= 1) return n;
  int a = 0, b = 1;
  for (int i = 2; i <= n; i++) {
    final temp = a + b;
    a = b;
    b = temp;
  }
  return b;
}

Map<String, dynamic> _getUserPreferences(String category) {
  final allPreferences = {
    'theme': {'mode': 'dark', 'primaryColor': 'deepPurple'},
    'notifications': {'enabled': true, 'sound': true},
    'privacy': {'analytics': false, 'crashReporting': true},
  };

  if (category == 'all') {
    return allPreferences;
  }

  return {category: allPreferences[category] ?? {}};
}
