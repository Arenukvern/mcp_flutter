// ignore_for_file: avoid_catches_without_on_clauses

import 'package:devtools_mcp_extension/common_imports.dart';

/// {@template inspector_app}
/// Root application widget for the Flutter Inspector
/// {@endtemplate}
class InspectorApp extends StatefulWidget {
  /// {@macro inspector_app}
  const InspectorApp({super.key});

  @override
  State<InspectorApp> createState() => _InspectorAppState();
}

class _InspectorAppState extends State<InspectorApp> {
  Future<RpcClientsOrchestrator>? _rpcClientsOrchestratorFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((final timeStamp) async {
      _rpcClientsOrchestratorFuture = _initRpcClients().whenComplete(() {
        setState(() {});
      });
    });
  }

  @override
  Widget build(final BuildContext context) => MaterialApp(
    title: 'Flutter Inspector',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: FutureBuilder(
      // ignore: discarded_futures
      future: _rpcClientsOrchestratorFuture,
      builder: (final context, final snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error initializing RPC servers: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final rpcOrchestrator = snapshot.data;
        if (rpcOrchestrator == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return ChangeNotifierProvider.value(
          value: rpcOrchestrator,
          child: const ServerDashboard(),
        );
      },
    ),
  );

  Future<RpcClientsOrchestrator> _initRpcClients() async {
    final orchestrator = RpcClientsOrchestrator();
    try {
      await orchestrator.initializeAll();
      return orchestrator;
    } catch (e, stackTrace) {
      print('Error starting RPC servers: $e, $stackTrace');
      // Still return the orchestrator even if there were errors,
      // so we can display connection status in the UI
      return orchestrator;
    }
  }
}
