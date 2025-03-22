import 'package:flutter_mcp_extension/common_imports.dart';
import 'package:flutter_mcp_extension/services/service_extension_bridge.dart';

/// {@template rpc_client_info}
/// Holds connection information for an RPC client
/// {@endtemplate}
class RpcClientInfo with ChangeNotifier {
  /// {@macro rpc_client_info}
  RpcClientInfo({
    required this.name,
    required this.host,
    required this.port,
    required this.path,
  });

  /// Name of the server (e.g., "Flutter" or "TypeScript")
  final String name;

  /// Current host value
  String host;

  /// Current port value
  int port;

  /// Current path value
  String path;

  /// The actual RPC client instance
  final client = RpcClient();

  /// Updates connection parameters and notifies listeners
  void updateConnection({
    final String? host,
    final int? port,
    final String? path,
  }) {
    if (host != null) this.host = host;
    if (port != null) this.port = port;
    if (path != null) this.path = path;
    notifyListeners();
  }

  /// Connect to the server using current parameters
  Future<void> connect() async {
    await client.connect(host: host, port: port, path: path);
  }

  /// Disconnect from the server
  Future<void> disconnect() async {
    await client.disconnect();
  }

  /// Restart the connection
  Future<void> restart() async {
    await disconnect();
    await connect();
  }
}

/// {@template rpc_clients_orchestrator}
/// Manages multiple RPC client connections
/// {@endtemplate}
class RpcClientsOrchestrator with ChangeNotifier {
  /// {@macro rpc_clients_orchestrator}
  RpcClientsOrchestrator() {
    // Initialize the TS client from environment variables
    // _tsClient = RpcClientInfo(
    //   name: 'TypeScript',
    //   host: Envs.tsRpc.host,
    //   port: Envs.tsRpc.port,
    //   path: Envs.tsRpc.path,
    // );

    // Create the service extension bridge using the TS client
    _serviceBridge = ServiceExtensionBridge(rpcClient: _tsClient.client);

    // Listen to changes in the clients
    // _tsClient.addListener(notifyListeners);
    _serviceBridge.addListener(notifyListeners);
  }

  late final ServiceExtensionBridge _serviceBridge;
  late final RpcClientInfo _tsClient;

  /// Service extension bridge for Flutter VM interaction
  ServiceExtensionBridge get serviceBridge => _serviceBridge;

  /// TypeScript RPC client information
  // RpcClientInfo get tsClient => _tsClient;

  /// Initialize and connect all clients
  Future<void> initializeAll() async {
    // Connect TS client
    // await _tsClient.connect();
    await _serviceBridge.connectToVmService();
  }

  /// Connect to the Flutter VM service
  Future<bool> connectToFlutterVmService() async =>
      _serviceBridge.connectToVmService();

  /// Disconnect from the Flutter VM service
  Future<void> disconnectFromFlutterVmService() async {
    await _serviceBridge.disconnectFromVmService();
  }

  @override
  void dispose() {
    // _tsClient.removeListener(notifyListeners);
    _serviceBridge.removeListener(notifyListeners);
    super.dispose();
  }
}
