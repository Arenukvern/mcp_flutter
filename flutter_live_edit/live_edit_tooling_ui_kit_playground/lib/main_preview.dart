// Preview-only entry: no LiveEditScope, no toolkit. Layer 1 only.
// Run: flutter run -t lib/main_preview.dart

import 'package:flutter/material.dart';

import 'src/preview/dumb_tool_layer.dart';

void main() => runApp(const PreviewOnlyApp());

/// App that shows only the dumb surface (fixture bubble + panel).
/// No [LiveEditScope], no [FlutterLiveEditHost], no toolkit dependency in this path.
class PreviewOnlyApp extends StatelessWidget {
  const PreviewOnlyApp({super.key});

  @override
  Widget build(final BuildContext context) => MaterialApp(
    title: 'Tooling UI Kit Preview',
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      body: LayoutBuilder(
        builder: (final _, final constraints) => Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Center(child: Text('Preview – no live edit')),
            DumbToolLayer(viewportSize: constraints.biggest),
          ],
        ),
      ),
    ),
  );
}
