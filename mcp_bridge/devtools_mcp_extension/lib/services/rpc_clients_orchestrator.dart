// ignore_for_file: avoid_catches_without_on_clauses

import 'package:devtools_mcp_extension/common_imports.dart';
import 'package:devtools_mcp_extension/services/custom_devtools_service.dart';
import 'package:devtools_mcp_extension/services/forwarding_rpc_listener.dart';
import 'package:mcp_dart_forwarding_client/mcp_dart_forwarding_client.dart';

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
    // Initialize the TypeScript client
    _dartVmDevtoolsService = DartVmDevtoolsService();
    customDevtoolsService = CustomDevtoolsService(
      devtoolsService: _dartVmDevtoolsService,
    );
    errorDevtoolsService = ErrorDevtoolsService(
      devtoolsService: _dartVmDevtoolsService,
    );
    // Initialize the forwarding service
    _forwardingClient = ForwardingClient(ForwardingClientType.flutter);
    _forwardingRpcListener = ForwardingRpcListener(
      forwardingClient: _forwardingClient,
      devtoolsService: _dartVmDevtoolsService,
      customDevtoolsService: customDevtoolsService,
      errorDevtoolsService: errorDevtoolsService,
    );
  }

  late final DartVmDevtoolsService _dartVmDevtoolsService;
  late final CustomDevtoolsService customDevtoolsService;
  late final ErrorDevtoolsService errorDevtoolsService;
  late final ForwardingClient _forwardingClient;
  late final ForwardingRpcListener _forwardingRpcListener;

  /// Service extension bridge for Flutter VM interaction
  DartVmDevtoolsService get serviceBridge => _dartVmDevtoolsService;

  /// Forwarding service for communication with flutter_inspector
  ForwardingClient get forwardingService => _forwardingClient;

  /// Initialize and connect all clients
  Future<void> initializeAll() async {
    // Connect to VM service
    await _dartVmDevtoolsService.connectToVmService();
    const forwardingServiceEnabled = false;
    if (forwardingServiceEnabled) await connectToForwardingService();
    await customDevtoolsService.init();
    await errorDevtoolsService.init();
  }

  @override
  Future<void> dispose() async {
    _dartVmDevtoolsService.dispose();
    await errorDevtoolsService.dispose();
  }

  /// Connect to the Flutter VM service
  Future<bool> connectToFlutterVmService() =>
      _dartVmDevtoolsService.connectToVmService();

  /// Disconnect from the Flutter VM service
  Future<void> disconnectFromFlutterVmService() async {
    await _dartVmDevtoolsService.disconnectFromVmService();
  }

  /// Connect to the forwarding service
  Future<void> connectToForwardingService({
    final String? host,
    final int? port,
    final String? path,
  }) async {
    final h = host ?? Envs.forwardingServer.host;
    final p = port ?? Envs.forwardingServer.port;
    final pth = path ?? Envs.forwardingServer.path;
    try {
      await _forwardingClient.connect(h, p, path: pth);
      _forwardingRpcListener.init();
      notifyListeners();
    } catch (e, stackTrace) {
      print(e);
      print(stackTrace);
    }
  }

  /// Disconnect from the forwarding service
  Future<void> disconnectFromForwardingService() async {
    _forwardingClient.disconnect();
    notifyListeners();
  }
}
