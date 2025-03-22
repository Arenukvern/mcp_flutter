import 'dart:async';

import 'package:flutter_mcp_extension/common_imports.dart';

/// {@template inspector_app}
/// Root application widget for the Flutter Inspector
/// {@endtemplate}
class InspectorApp extends StatelessWidget {
  /// {@macro inspector_app}
  const InspectorApp({super.key});

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
      future: _initRpcClients(),
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

        final rpcOrchestrator = snapshot.data!;

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
    } catch (e) {
      print('Error starting RPC servers: $e');
      // Still return the orchestrator even if there were errors,
      // so we can display connection status in the UI
      return orchestrator;
    }
  }
}
