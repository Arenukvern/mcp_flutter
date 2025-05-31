import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

/// Example demonstrating how to register a Fibonacci calculator tool
/// with the MCP toolkit for automatic discovery by the MCP server
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the MCP toolkit
  MCPToolkitBinding.instance
    ..initialize()
    ..initializeFlutterToolkit();

  // Register the Fibonacci calculator tool
  await _registerFibonacciTool();

  runApp(const FibonacciApp());
}

/// Register the Fibonacci calculator tool with the MCP toolkit
Future<void> _registerFibonacciTool() async {
  final fibonacciEntry = MCPCallEntry(
    methodName: const MCPMethodName('calculate_fibonacci'),
    handler: (final request) {
      final n = int.tryParse(request['n'] ?? '0') ?? 0;
      
      if (n < 0) {
        return MCPCallResult(
          message: 'Error: Fibonacci position must be non-negative',
          parameters: {'error': 'Invalid input: $n'},
        );
      }
      
      if (n > 100) {
        return MCPCallResult(
          message: 'Error: Fibonacci position too large (max 100)',
          parameters: {'error': 'Input too large: $n'},
        );
      }

      final result = _calculateFibonacci(n);
      return MCPCallResult(
        message: 'Calculated Fibonacci number for position $n',
        parameters: {
          'result': result,
          'position': n,
          'sequence': _getFibonacciSequence(n),
        },
      );
    },
    toolDefinition: MCPToolDefinition(
      name: 'calculate_fibonacci',
      description: 'Calculate the nth Fibonacci number and return the sequence',
      inputSchema: {
        'type': 'object',
        'properties': {
          'n': {
            'type': 'integer',
            'description': 'The position in the Fibonacci sequence (0-100)',
            'minimum': 0,
            'maximum': 100,
          },
        },
        'required': ['n'],
      },
    ),
  );

  // Register the tool - it will be automatically discovered by the MCP server
  await MCPToolkitBinding.instance.addEntries(
    entries: {fibonacciEntry},
  );

  debugPrint('✅ Fibonacci calculator tool registered with MCP toolkit');
}

/// Calculate the nth Fibonacci number
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

/// Get the Fibonacci sequence up to position n
List<int> _getFibonacciSequence(final int n) {
  if (n < 0) return [];
  if (n == 0) return [0];
  
  final sequence = <int>[0, 1];
  
  for (var i = 2; i <= n; i++) {
    sequence.add(sequence[i - 1] + sequence[i - 2]);
  }
  
  return sequence;
}

/// Simple Flutter app that displays the Fibonacci tool status
class FibonacciApp extends StatelessWidget {
  const FibonacciApp({super.key});

  @override
  Widget build(final BuildContext context) => MaterialApp(
    title: 'Fibonacci MCP Tool',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
    ),
    home: const FibonacciHomePage(),
  );
}

/// Home page showing the tool registration status
class FibonacciHomePage extends StatelessWidget {
  const FibonacciHomePage({super.key});

  @override
  Widget build(final BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Fibonacci MCP Tool'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
    ),
    body: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.functions,
            size: 64,
            color: Colors.blue,
          ),
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