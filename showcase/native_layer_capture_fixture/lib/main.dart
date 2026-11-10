import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

/// Minimal native-layer proof fixture: one increment control, one counter, no
/// IntentCall path dependencies. Debug banner is off so the green stripe ROI
/// stays all-marker (#22AA55) in flutter_layer captures.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MCPToolkitBinding.instance
    ..initialize()
    ..initializeFlutterToolkit();
  runApp(const NativeLayerCaptureFixtureApp());
}

const Color kMarkerStripe = Color(0xFF22AA55);

class NativeLayerCaptureFixtureApp extends StatefulWidget {
  const NativeLayerCaptureFixtureApp({super.key});

  @override
  State<NativeLayerCaptureFixtureApp> createState() =>
      _NativeLayerCaptureFixtureAppState();
}

class _NativeLayerCaptureFixtureAppState
    extends State<NativeLayerCaptureFixtureApp> {
  int _counter = 0;

  void _increment() => setState(() => _counter++);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              identifier: 'native_layer_marker_stripe',
              child: Container(height: 8, color: kMarkerStripe),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Semantics(
                    identifier: 'native_layer_counter_value',
                    label: 'Counter',
                    value: '$_counter',
                    child: Text(
                      '$_counter',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    identifier: 'native_layer_increment_button',
                    button: true,
                    onTap: _increment,
                    child: ElevatedButton(
                      onPressed: _increment,
                      child: const Text('Increment'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
