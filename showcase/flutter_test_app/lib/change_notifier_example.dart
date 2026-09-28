import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:provider/provider.dart';

var _customNotifierToolRegistered = false;

class CustomNotifier with ChangeNotifier {
  CustomNotifier() {
    if (_customNotifierToolRegistered) {
      return;
    }
    _customNotifierToolRegistered = true;
    // to see this tool in MCP tools, if you use Cursor
    // use --await-dnd flag (see more https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_server_dart/README.md#L197)
    // This will force MCP to wait for connection to the Dart VM server.
    //
    // Otherwise, this is example rule which will instruct Agent
    // to use and understand dynamic MCP tools.
    //
    // https://github.com/Arenukvern/mcp_flutter/blob/main/.cursor/rules/mcp_dynamic_tools.mdc
    //
    // See more about MCP dynamic tools:
    // https://github.com/Arenukvern/mcp_flutter/blob/main/QUICK_START.md#dynamic-tools-registration
    final yourTool = mcpToolkitTool(
      namespace: 'app',
      handler: (request) {
        return MCPCallResult(
          message: 'See CustomNotifier state',
          // should be json serializable map.
          // during transfer, this object will be encoded to json via
          // jsonEncode.
          parameters: {'counter': counter},
        );
      },
      definition: MCPToolDefinition(
        // should be unique.
        name: 'get_custom_notifier_state',
        description: 'Get runtime data state from CustomNotifier',
        inputSchema: ObjectSchema(properties: {}, required: []),
      ),
    );

    MCPToolkitBinding.instance.addEntries(entries: {yourTool});
  }

  var _counter = 0;

  int get counter => _counter;

  void increment() {
    _counter++;
    notifyListeners();
  }
}

// ChangeNotifier counter example
class ChangeNotifierCounterWidget extends StatelessWidget {
  const ChangeNotifierCounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final counter = context.select<CustomNotifier, int>(
      (notifier) => notifier.counter,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'ChangeNotifier',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '$counter',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: context.read<CustomNotifier>().increment,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Increment'),
          ),
        ],
      ),
    );
  }
}
