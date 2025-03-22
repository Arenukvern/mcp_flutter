import 'package:flutter/services.dart';
import 'package:flutter_mcp_extension/common_imports.dart';
import 'package:flutter_mcp_extension/services/service_extension_bridge.dart';

/// {@template rpc_connection_status}
/// Displays real-time RPC connection status with animated indicators
/// {@endtemplate}
class RpcConnectionStatus extends StatelessWidget {
  /// {@macro rpc_connection_status}
  const RpcConnectionStatus({required this.client, super.key});

  /// The RPC client to monitor
  final RpcClient client;

  @override
  Widget build(final BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        client.connected ? Icons.cloud_done : Icons.cloud_off,
        color: client.connected ? Colors.green : Colors.red,
        size: 28,
      ),
      const SizedBox(width: 8),
      Text(
        client.connected ? 'Connected' : 'Disconnected',
        style: TextStyle(
          color: client.connected ? Colors.green : Colors.red,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

/// {@template vm_service_connection_status}
/// Displays real-time VM service connection status
/// {@endtemplate}
class VmServiceConnectionStatus extends StatelessWidget {
  /// {@macro vm_service_connection_status}
  const VmServiceConnectionStatus({required this.serviceBridge, super.key});

  /// The service bridge to monitor
  final ServiceExtensionBridge serviceBridge;

  @override
  Widget build(final BuildContext context) {
    // Get the connected state from service manager
    final connectedState = serviceBridge.serviceManager.connectedState;

    // Use AnimatedBuilder to rebuild when connection state changes
    return AnimatedBuilder(
      animation: connectedState,
      builder: (final context, _) {
        final isConnected = connectedState.value.connected;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isConnected ? Icons.flutter_dash : Icons.flutter_dash_outlined,
              color: isConnected ? Colors.blue : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              isConnected ? 'VM Connected' : 'VM Disconnected',
              style: TextStyle(
                color: isConnected ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// {@template server_dashboard}
/// Main server dashboard screen showing connection status and controls
/// {@endtemplate}
class ServerDashboard extends StatelessWidget {
  /// {@macro server_dashboard}
  const ServerDashboard({super.key});

  @override
  Widget build(final BuildContext context) {
    final orchestrator = context.watch<RpcClientsOrchestrator>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('RPC Servers Dashboard'),
        actions: const [
          // RpcConnectionStatus(client: orchestrator.tsClient.client),
          SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // TypeScript server card
            // _ServerCard(clientInfo: orchestrator.tsClient),
            const SizedBox(height: 24),

            // VM Service bridge card
            _VmServiceBridgeCard(serviceBridge: orchestrator.serviceBridge),

            const SizedBox(height: 24),

            // Registered methods section
            const Text(
              'Registered Methods',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _MethodsList(
              // tsClient: orchestrator.tsClient.client,
              vmServiceBridge: orchestrator.serviceBridge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Server status item with icon, label and value
class _ServerStatusItem extends StatelessWidget {
  const _ServerStatusItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(final BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: Colors.blueGrey),
      const SizedBox(width: 8),
      Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(width: 8),
      Expanded(child: Text(value)),
    ],
  );
}

/// {@template server_card}
/// Card displaying server status and controls
/// {@endtemplate}
class _ServerCard extends StatefulWidget {
  /// {@macro server_card}
  const _ServerCard({required this.clientInfo});

  /// The client information to display
  final RpcClientInfo clientInfo;

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _pathController;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.clientInfo.host);
    _portController = TextEditingController(
      text: widget.clientInfo.port.toString(),
    );
    _pathController = TextEditingController(text: widget.clientInfo.path);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${widget.clientInfo.name} Server',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              RpcConnectionStatus(client: widget.clientInfo.client),
            ],
          ),
          const Divider(),

          // Connection parameters
          const Text(
            'Connection Settings',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Host input
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Host',
              prefixIcon: Icon(Icons.public),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),

          // Port input
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: 'Port',
              prefixIcon: Icon(Icons.numbers),
              border: OutlineInputBorder(),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 8),

          // Path input
          TextField(
            controller: _pathController,
            decoration: const InputDecoration(
              labelText: 'Path',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Update'),
                onPressed: () {
                  widget.clientInfo.updateConnection(
                    host: _hostController.text,
                    port:
                        int.tryParse(_portController.text) ??
                        widget.clientInfo.port,
                    path: _pathController.text,
                  );
                },
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Restart'),
                onPressed: () async {
                  await widget.clientInfo.restart();
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// {@template vm_service_bridge_card}
/// Card displaying VM service bridge status and controls
/// {@endtemplate}
class _VmServiceBridgeCard extends StatefulWidget {
  /// {@macro vm_service_bridge_card}
  const _VmServiceBridgeCard({required this.serviceBridge});

  /// The service bridge to display
  final ServiceExtensionBridge serviceBridge;

  @override
  State<_VmServiceBridgeCard> createState() => _VmServiceBridgeCardState();
}

class _VmServiceBridgeCardState extends State<_VmServiceBridgeCard> {
  late TextEditingController _uriController;

  @override
  void initState() {
    super.initState();
    _uriController = TextEditingController(
      text:
          'ws://${Envs.flutterRpc.host}:${Envs.flutterRpc.port}/${Envs.flutterRpc.path}',
    );
  }

  @override
  void dispose() {
    _uriController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    // Get the connected state from service manager for real-time updates
    final connectedState = widget.serviceBridge.serviceManager.connectedState;

    return AnimatedBuilder(
      animation: connectedState,
      builder: (final context, _) {
        final isConnected = connectedState.value.connected;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Flutter VM Service',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    VmServiceConnectionStatus(
                      serviceBridge: widget.serviceBridge,
                    ),
                  ],
                ),
                const Divider(),

                // Connection parameters
                const Text(
                  'VM Service URI',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // URI input
                TextField(
                  controller: _uriController,
                  decoration: const InputDecoration(
                    labelText: 'WebSocket URI',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                    hintText: 'ws://localhost:8181/ws',
                  ),
                ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isConnected)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text('Disconnect'),
                        onPressed: () async {
                          await widget.serviceBridge.disconnectFromVmService();
                        },
                      )
                    else
                      FilledButton.icon(
                        icon: const Icon(Icons.connecting_airports),
                        label: const Text('Connect'),
                        onPressed: () async {
                          try {
                            final uri = Uri.parse(_uriController.text);
                            await widget.serviceBridge.connectToVmService(uri);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error connecting: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Displays registered RPC methods
class _MethodsList extends StatelessWidget {
  const _MethodsList({
    // required this.tsClient,
    required this.vmServiceBridge,
  });

  // final RpcClient tsClient;
  final ServiceExtensionBridge vmServiceBridge;

  @override
  Widget build(final BuildContext context) {
    // final tsMethods = tsClient.registeredMethods;
    final bridgeMethods = vmServiceBridge.rpcClient.registeredMethods;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // if (tsMethods.isEmpty && bridgeMethods.isEmpty)
            //   const Text(
            //     'No methods registered yet',
            //     style: TextStyle(fontStyle: FontStyle.italic),
            //   )
            // else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // if (tsMethods.isNotEmpty) ...[
                //   const Text(
                //     'TypeScript Server Methods',
                //     style: TextStyle(fontWeight: FontWeight.bold),
                //   ),
                //   const SizedBox(height: 8),
                //   ..._buildMethodsList(tsMethods),
                //   const SizedBox(height: 16),
                // ],
                if (bridgeMethods.isNotEmpty) ...[
                  const Text(
                    'VM Service Bridge Methods',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._buildMethodsList(bridgeMethods),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMethodsList(final List<String> methods) => [
    for (final method in methods)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.api, size: 18, color: Colors.blueGrey),
            const SizedBox(width: 8),
            Text(method),
          ],
        ),
      ),
  ];
}
