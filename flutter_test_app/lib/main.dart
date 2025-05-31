import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit(); // Adds Flutter related methods to the MCP server

      // Register initial custom tools dynamically
      await _registerCustomTools();

      runApp(const MyApp());

      // Register additional tools after a delay to test auto-registration
      Timer(const Duration(seconds: 5), () async {
        await _registerAdditionalTools();
      });
    },
    (error, stack) {
      // Optionally, you can also use the bridge's error handling for zone errors
      MCPToolkitBinding.instance.handleZoneError(error, stack);
    },
  );
}

/// Register custom tools with the MCP server
Future<void> _registerCustomTools() async {
  final binding = MCPToolkitBinding.instance;

  // Wait a bit for the connection to establish
  await Future.delayed(const Duration(seconds: 1));

  // Create MCPCallEntry objects with proper handlers
  final fibonacciEntry = MCPCallEntry(
    methodName: const MCPMethodName('calculate_fibonacci'),
    handler: (request) {
      final n = int.tryParse(request['n'] ?? '0') ?? 0;
      final result = _calculateFibonacci(n);
      return MCPCallResult(
        message: 'Calculated Fibonacci number for position $n',
        parameters: {'result': result, 'position': n},
      );
    },
    toolDefinition: MCPToolDefinition(
      name: 'calculate_fibonacci',
      description: 'Calculate the nth Fibonacci number',
      inputSchema: {
        'type': 'object',
        'properties': {
          'n': {
            'type': 'integer',
            'description': 'The position in the Fibonacci sequence',
            'minimum': 0,
            'maximum': 100,
          },
        },
        'required': ['n'],
      },
    ),
  );

  // Create app state resource entry
  final appStateEntry = MCPCallEntry(
    methodName: const MCPMethodName('app_state'),
    handler: (request) {
      return MCPCallResult(
        message: 'Current application state and configuration',
        parameters: {
          'appName': 'MCP Toolkit Demo',
          'isConnected': true, // Always true since we use service extensions
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    },
    resourceDefinition: MCPResourceDefinition(
      name: 'App State',
      description: 'Current application state and configuration',
      mimeType: 'application/json',
    ),
  );

  // Register all entries
  await binding.addEntries(entries: {fibonacciEntry, appStateEntry});

  print('Initial custom tools and resources registration completed');
}

/// Register additional tools after delay to test auto-registration
Future<void> _registerAdditionalTools() async {
  final binding = MCPToolkitBinding.instance;

  // Create user preferences tool entry
  final preferencesEntry = MCPCallEntry(
    methodName: const MCPMethodName('get_user_preferences'),
    handler: (request) {
      final category = request['category'] ?? 'all';
      final preferences = _getUserPreferences(category);
      return MCPCallResult(
        message: 'User preferences for category: $category',
        parameters: {'preferences': preferences, 'category': category},
      );
    },
    toolDefinition: MCPToolDefinition(
      name: 'get_user_preferences',
      description: 'Get user preferences and settings',
      inputSchema: {
        'type': 'object',
        'properties': {
          'category': {
            'type': 'string',
            'description': 'Preference category to retrieve',
            'enum': ['theme', 'notifications', 'privacy', 'all'],
          },
        },
      },
    ),
  );

  // Create system info tool
  final systemInfoEntry = MCPCallEntry(
    methodName: const MCPMethodName('get_system_info'),
    handler: (request) {
      return MCPCallResult(
        message: 'System information',
        parameters: {
          'platform': 'Flutter',
          'version': '3.0.0',
          'buildMode': 'debug',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    },
    toolDefinition: MCPToolDefinition(
      name: 'get_system_info',
      description: 'Get system and app information',
      inputSchema: {'type': 'object', 'properties': {}},
    ),
  );

  // Register additional entries - this should trigger auto-registration
  await binding.addEntries(entries: {preferencesEntry, systemInfoEntry});

  print(
    'Additional tools registration completed - should trigger auto-registration event',
  );
}

/// Calculate Fibonacci number
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

/// Get user preferences based on category
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
      home: const MyHomePage(title: 'MCP Dynamic Registration Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
    // Check connection status periodically
    Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnectionStatus();
    });
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _checkConnectionStatus() {
    setState(() {});
  }

  Future<void> _registerNewTool() async {
    final binding = MCPToolkitBinding.instance;

    try {
      final toolName = 'counter_value_${DateTime.now().millisecondsSinceEpoch}';
      final counterEntry = MCPCallEntry(
        methodName: MCPMethodName(toolName),
        handler: (request) {
          return MCPCallResult(
            message: 'Current counter value from Flutter app',
            parameters: {
              'counter': _counter,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        },
        toolDefinition: MCPToolDefinition(
          name: toolName,
          description: 'Get the current counter value from the Flutter app',
          inputSchema: const {'type': 'object', 'properties': {}},
        ),
      );

      await binding.addEntries(entries: {counterEntry});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully registered new tool!'),
            backgroundColor: Colors.green,
          ),
        );
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

    _checkConnectionStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'This app demonstrates dynamic MCP tool registration using the official dart_mcp package.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),
            const Text('Counter value:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _registerNewTool,
              child: const Text('Register New Tool'),
            ),

            const SizedBox(height: 20),
            Text(
              'Local Entries: ${MCPToolkitBinding.instance.allEntries.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            if (MCPToolkitBinding.instance.allEntries.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Registered Service Extensions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...MCPToolkitBinding.instance.allEntries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${entry.key}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
