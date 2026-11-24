/// Shared Fibonacci custom-tool registration for docs and integration tests.
///
/// Canonical runnable UI: [example/fibonacci_tool_example.dart](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_toolkit/example/fibonacci_tool_example.dart).
library;

import 'package:mcp_toolkit/mcp_toolkit.dart';

/// Registers `app/calculate_fibonacci` — used by the pub.dev example app and
/// `showcase/flutter_test_app` (integration catalog validation only).
AgentCallEntry buildCalculateFibonacciTool() => mcpToolkitTool(
  namespace: 'app',
  definition: MCPToolDefinition(
    name: 'calculate_fibonacci',
    description:
        'Calculate the nth Fibonacci number (integration + schema validation)',
    inputSchema: ObjectSchema(
      properties: {
        'n': IntegerSchema(
          description: 'The position in the Fibonacci sequence (0-100)',
          minimum: 0,
          maximum: 100,
        ),
      },
      required: ['n'],
    ),
  ),
  handler: (request) {
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
    return MCPCallResult(
      message: 'Calculated Fibonacci number for position $n',
      parameters: {'result': _fibonacci(n), 'position': n},
    );
  },
);

int _fibonacci(int n) {
  if (n <= 1) return n;
  var a = 0;
  var b = 1;
  for (var i = 2; i <= n; i++) {
    final t = a + b;
    a = b;
    b = t;
  }
  return b;
}