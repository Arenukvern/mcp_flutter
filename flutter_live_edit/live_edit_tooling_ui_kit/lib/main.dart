import 'package:flutter/material.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';

void main() => runApp(const LiveEditToolingUiKitApp());

/// App that shows only the live-edit tool layer (bubble + panel) with prefilled
/// data. Run it, connect live-edit (and MCP), and iteratively improve the
/// tooling UI; same keys/semantics as the main app's tool layer.
class LiveEditToolingUiKitApp extends StatelessWidget {
  const LiveEditToolingUiKitApp({super.key});

  @override
  Widget build(final BuildContext context) => MaterialApp(
    title: 'Live Edit Tooling UI Kit',
    theme: ThemeData(useMaterial3: true),
    home: const _ToolingUiKitScreen(),
  );
}

class _ToolingUiKitScreen extends StatefulWidget {
  const _ToolingUiKitScreen();

  @override
  State<_ToolingUiKitScreen> createState() => _ToolingUiKitScreenState();
}

class _ToolingUiKitScreenState extends State<_ToolingUiKitScreen> {
  late final LiveEditOrchestrator _orchestrator;

  @override
  void initState() {
    super.initState();
    _orchestrator = LiveEditOrchestrator();
    _orchestrator.prefillForToolingShowcase();
  }

  @override
  void dispose() {
    _orchestrator.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => Scaffold(
    body: FlutterLiveEditHost(
      orchestrator: _orchestrator,
      childIsToolLayer: true,
      child: ListenableBuilder(
        listenable: _orchestrator,
        builder: (final _, final child) => LayoutBuilder(
          builder: (final context, final constraints) => LiveEditToolLayer(
            orchestrator: _orchestrator,
            viewportSize: constraints.biggest,
            buildPropertyPanelSection: null,
          ),
        ),
      ),
    ),
  );
}
