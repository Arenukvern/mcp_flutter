import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

/// The showcase demo app: a deliberately small instrumented target the
/// harness drives end-to-end (`showcase/drivers/bin/drive_flutter.dart`).
///
/// Every control carries a plain text label so a `ToolkitDriver` can
/// resolve it by name off a semantic snapshot: tap `Increment`, type into
/// `Name`, navigate the named route `/profile`, and verify rendered text.
/// `MCPToolkitBinding` registers the `ext.mcp.toolkit.*` service
/// extensions the toolkit's drivers and MCP server speak.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MCPToolkitBinding.instance
    ..initialize()
    ..initializeFlutterToolkit()
    ..navigatorKey = demoNavigatorKey;
  runApp(const FlutterDemoApp());
}

/// Registered with [MCPToolkitBinding.instance] so the toolkit's
/// `navigate` extension can push the named routes below.
final GlobalKey<NavigatorState> demoNavigatorKey = GlobalKey<NavigatorState>();

class FlutterDemoApp extends StatelessWidget {
  const FlutterDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Flutter MCP Toolkit Demo',
    navigatorKey: demoNavigatorKey,
    home: const HomeScreen(),
    routes: <String, WidgetBuilder>{'/profile': (_) => const ProfileScreen()},
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _count = 0;
  final TextEditingController _name = TextEditingController();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Flutter demo home')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: <Widget>[
          Text('Count: $_count', style: Theme.of(context).textTheme.headlineSmall),
          ElevatedButton(
            onPressed: () => setState(() => _count++),
            child: const Text('Increment'),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed(
              '/profile',
              arguments: _name.text.isEmpty ? 'friend' : _name.text,
            ),
            child: const Text('Open profile'),
          ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final name =
        ModalRoute.of(context)?.settings.arguments as String? ?? 'friend';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: <Widget>[
            Text('Hello, $name!', style: Theme.of(context).textTheme.headlineSmall),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
