import 'package:flutter/material.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';

import 'src/preview/dumb_tool_layer.dart';

void main() => runApp(const LiveEditToolingUiKitApp());

/// Live-edit mode: main surface is the dumb bubble + panel (Layer 1);
/// Layer 2 is the wired tool layer overlay from the host.
class LiveEditToolingUiKitApp extends StatelessWidget {
  const LiveEditToolingUiKitApp({super.key});

  @override
  Widget build(final BuildContext context) => MaterialApp(
    title: 'Live Edit Tooling UI Kit',
    theme: ThemeData(useMaterial3: true),
    home: const _LiveEditToolingScreen(),
  );
}

class _LiveEditToolingScreen extends StatefulWidget {
  const _LiveEditToolingScreen();

  @override
  State<_LiveEditToolingScreen> createState() => _LiveEditToolingScreenState();
}

class _LiveEditToolingScreenState extends State<_LiveEditToolingScreen> {
  bool _prefilled = false;

  void _prefillPlayground(final LiveEditContext context) {
    StartSessionCommand(
      targetDomain: LiveEditTargetDomain.appScene,
    ).execute(context);
    SetOverlayEnabledCommand(enabled: true).execute(context);
    ExpandPanelCommand().execute(context);
  }

  @override
  Widget build(final BuildContext context) => LiveEditScope(
    child: Scaffold(
      body: FlutterLiveEditHost(
        orchestrator: null,
        childIsToolLayer: false,
        child: Builder(
          builder: (final ctx) {
            final scope = LiveEditScope.of(ctx);
            if (!_prefilled) {
              _prefilled = true;
              WidgetsBinding.instance.addPostFrameCallback((final _) {
                _prefillPlayground(scope.context);
              });
            }
            return LayoutBuilder(
              builder: (final _, final constraints) =>
                  DumbToolLayer(viewportSize: constraints.biggest),
            );
          },
        ),
      ),
    ),
  );
}
