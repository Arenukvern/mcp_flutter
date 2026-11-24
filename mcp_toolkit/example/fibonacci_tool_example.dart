import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:mcp_toolkit/examples/fibonacci.dart';

Future<void> main() async {
  await MCPToolkitBinding.instance.addEntries(entries: _starterEntries);
  await MCPToolkitBinding.instance.bootstrapFlutter(
    runApp: () => runApp(const FibonacciApp()),
  );
}

Set<AgentCallEntry> get _starterEntries => {
  buildCalculateFibonacciTool(),
  mcpToolkitResource(
    namespace: 'app',
    definition: MCPResourceDefinition(
      name: 'app_runtime_status',
      description: 'Read-only runtime diagnostics for the starter app',
      mimeType: 'application/json',
    ),
    handler: (request) => MCPCallResult(
      message: 'Starter app runtime diagnostics',
      parameters: {
        'appName': 'Fibonacci MCP Tool',
        'buildMode': kReleaseMode ? 'release' : 'debug',
        'toolCount': 1,
        'resourceCount': 1,
      },
    ),
  ),
};

class FibonacciApp extends StatelessWidget {
  const FibonacciApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Fibonacci MCP Tool',
    theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
    home: const FibonacciHomePage(),
  );
}

/// Home page showing the tool registration status
class FibonacciHomePage extends StatelessWidget {
  const FibonacciHomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Fibonacci MCP Tool'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
    ),
    body: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.functions, size: 64, color: Colors.blue),
          SizedBox(height: 16),
          Text(
            'Fibonacci Calculator Tool',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Tool registered with MCP server',
            style: TextStyle(fontSize: 16, color: Colors.green),
          ),
          SizedBox(height: 24),
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available via MCP:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Tool: calculate_fibonacci'),
                  Text('• Input: n (integer, 0-100)'),
                  Text('• Output: Fibonacci number and sequence'),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
