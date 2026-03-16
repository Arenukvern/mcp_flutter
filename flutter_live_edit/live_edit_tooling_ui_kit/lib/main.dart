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
  bool _prefilled = false;

  @override
  Widget build(final BuildContext context) => LiveEditScope(
    child: Scaffold(
      body: FlutterLiveEditHost(
        orchestrator: null,
        childIsToolLayer: true,
        child: Builder(
          builder: (final ctx) {
            final scope = LiveEditScope.of(ctx);
            if (!_prefilled) {
              _prefilled = true;
              WidgetsBinding.instance.addPostFrameCallback((final _) {
                PrefillToolingShowcaseCommand().execute(scope.context);
              });
            }
            return ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[
                scope.sessionResource,
                scope.selectionResource,
                scope.draftResource,
                scope.bubbleResource,
                scope.panelViewResource,
                scope.backendConfigResource,
              ]),
              builder: (final _, final __) => LayoutBuilder(
                builder: (final _, final constraints) => LiveEditToolLayer(
                  context: scope.context,
                  controller: scope.controller,
                  viewportSize: constraints.biggest,
                  buildPropertyPanelSection: null,
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
