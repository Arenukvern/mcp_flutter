// ignore_for_file: avoid_catches_without_on_clauses

import 'package:devtools_mcp_extension/common_imports.dart';
import 'package:mcp_dart_forwarding_client/mcp_dart_forwarding_client.dart';

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
        size: 20,
      ),
      const SizedBox(width: 4),
      Text(
        client.connected ? 'Connected' : 'Disconnected',
        style: TextStyle(
          color: client.connected ? Colors.green : Colors.red,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    ],
  );
}

/// {@template forwarding_client_status}
/// Displays real-time forwarding client connection status
/// {@endtemplate}
class ForwardingClientStatus extends StatelessWidget {
  /// {@macro forwarding_client_status}
  const ForwardingClientStatus({required this.forwardingClient, super.key});

  /// The forwarding client to monitor
  final ForwardingClient forwardingClient;

  @override
  Widget build(final BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        forwardingClient.isConnected()
            ? Icons.swap_horiz
            : Icons.swap_horiz_outlined,
        color: forwardingClient.isConnected() ? Colors.orange : Colors.grey,
        size: 20,
      ),
      const SizedBox(width: 4),
      Text(
        forwardingClient.isConnected() ? 'Forwarding' : 'Disconnected',
        style: TextStyle(
          color: forwardingClient.isConnected() ? Colors.orange : Colors.grey,
          fontWeight: FontWeight.w500,
          fontSize: 13,
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
  final DartVmDevtoolsService serviceBridge;

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
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              isConnected ? 'VM' : 'VM Off',
              style: TextStyle(
                color: isConnected ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.w500,
                fontSize: 13,
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
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          VmServiceConnectionStatus(serviceBridge: orchestrator.serviceBridge),
          const SizedBox(width: 8),
          ForwardingClientStatus(
            forwardingClient: orchestrator.forwardingService,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          spacing: 16,
          children: [
            // Forwarding client card
            Flexible(
              child: _ForwardingClientCard(
                forwardingClient: orchestrator.forwardingService,
              ),
            ),
            // VM Service bridge card
            Flexible(
              child: _VmServiceBridgeCard(
                serviceBridge: orchestrator.serviceBridge,
              ),
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
      Icon(icon, size: 16, color: Colors.blueGrey),
      const SizedBox(width: 4),
      Text(
        '$label:',
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),
      const SizedBox(width: 4),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
    ],
  );
}

/// {@template forwarding_client_card}
/// Card displaying forwarding client status and controls
/// {@endtemplate}
class _ForwardingClientCard extends StatefulWidget {
  /// {@macro forwarding_client_card}
  const _ForwardingClientCard({required this.forwardingClient});

  /// The forwarding client to display
  final ForwardingClient forwardingClient;

  @override
  State<_ForwardingClientCard> createState() => _ForwardingClientCardState();
}

class _ForwardingClientCardState extends State<_ForwardingClientCard> {
  late TextEditingController _uriController;

  @override
  void initState() {
    super.initState();
    _uriController = TextEditingController(
      text:
          'ws://${Envs.forwardingServer.host}:${Envs.forwardingServer.port}/${Envs.forwardingServer.path}',
    );
  }

  @override
  void dispose() {
    _uriController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => Card(
    elevation: 1,
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Forwarding Service',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ForwardingClientStatus(forwardingClient: widget.forwardingClient),
            ],
          ),
          const Divider(height: 16),

          // Connection parameters
          const Text(
            'WebSocket URI',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          ),
          const SizedBox(height: 4),

          // URI input
          TextField(
            controller: _uriController,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
              hintText: 'ws://localhost:8143/forward',
            ),
          ),

          const SizedBox(height: 8),

          // Client info
          _ServerStatusItem(
            icon: Icons.fingerprint,
            label: 'Client ID',
            value: widget.forwardingClient.getClientId(),
          ),
          const SizedBox(height: 4),
          _ServerStatusItem(
            icon: Icons.category,
            label: 'Client Type',
            value: widget.forwardingClient.getClientType().toString(),
          ),

          const SizedBox(height: 8),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.forwardingClient.isConnected())
                OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text(
                    'Disconnect',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                  ),
                  onPressed: () async {
                    final orchestrator = context.read<RpcClientsOrchestrator>();
                    await orchestrator.disconnectFromForwardingService();
                  },
                )
              else
                FilledButton.icon(
                  icon: const Icon(Icons.connecting_airports, size: 16),
                  label: const Text('Connect', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                  ),
                  onPressed: () async {
                    try {
                      final uri = Uri.parse(_uriController.text);
                      final orchestrator =
                          context.read<RpcClientsOrchestrator>();
                      await orchestrator.connectToForwardingService(
                        host: uri.host,
                        port: uri.port,
                        path: uri.path,
                      );
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
}

/// {@template vm_service_bridge_card}
/// Card displaying VM service bridge status and controls
/// {@endtemplate}
class _VmServiceBridgeCard extends StatefulWidget {
  /// {@macro vm_service_bridge_card}
  const _VmServiceBridgeCard({required this.serviceBridge});

  /// The service bridge to display
  final DartVmDevtoolsService serviceBridge;

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
    final orchestrator = context.watch<RpcClientsOrchestrator>();

    return AnimatedBuilder(
      animation: connectedState,
      builder: (final context, _) {
        final isConnected = connectedState.value.connected;

        return Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Flutter VM Service',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    VmServiceConnectionStatus(
                      serviceBridge: widget.serviceBridge,
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Connection parameters
                const Text(
                  'WebSocket URI',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                ),
                const SizedBox(height: 4),

                // URI input
                TextField(
                  controller: _uriController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                    hintText: 'ws://localhost:8181/ws',
                  ),
                ),

                const SizedBox(height: 8),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isConnected)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text(
                          'Disconnect',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 28),
                        ),
                        onPressed: () async {
                          await widget.serviceBridge.disconnectFromVmService();
                        },
                      )
                    else
                      FilledButton.icon(
                        icon: const Icon(Icons.connecting_airports, size: 16),
                        label: const Text(
                          'Connect',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 28),
                        ),
                        onPressed: () async {
                          try {
                            final uri = Uri.parse(_uriController.text);
                            await widget.serviceBridge.connectToVmService(uri);
                          } catch (e, stackTrace) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error connecting: $e, $stackTrace',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    FilledButton.tonal(
                      onPressed: () async {
                        // await orchestrator.customDevtoolsService
                        //     .getVisualErrors({});
                        await orchestrator.customDevtoolsService
                            .callPlaygroundFunction({});
                      },
                      child: const Text('Custom Method'),
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
