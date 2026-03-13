import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

// StatefulWidget counter example
class StatefulCounterWidget extends StatefulWidget {
  const StatefulCounterWidget({super.key});

  @override
  State<StatefulCounterWidget> createState() => _StatefulCounterWidgetState();
}

class _StatefulCounterWidgetState extends State<StatefulCounterWidget> {
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _registerCounterTool();
  }

  void _registerCounterTool() {
    addMcpTool(
      MCPCallEntry.tool(
        handler: (request) {
          return MCPCallResult(
            message: 'StatefulWidget counter value',
            parameters: {'counter': _counter},
          );
        },
        definition: MCPToolDefinition(
          name: 'get_stateful_counter',
          description: 'Get the current StatefulWidget counter value',
          inputSchema: ObjectSchema(properties: {}),
        ),
      ),
    );
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'stateful_counter_root',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Semantics(
              identifier: 'stateful_counter_heading',
              child: Text(
                'StatefulWidget',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              identifier: 'stateful_counter_value',
              child: Text(
                '$_counter',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              identifier: 'stateful_counter_increment_button',
              child: ElevatedButton.icon(
                onPressed: _incrementCounter,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Increment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
