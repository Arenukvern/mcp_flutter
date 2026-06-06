// mcp_server_dart/lib/src/cli/codegen_snippets.dart

class CodegenSnippets {
  static const String flutterMainInit = '''
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit();
      runApp(const MyApp());
    },
    (error, stack) =>
        MCPToolkitBinding.instance.handleZoneError(error, stack),
  );
}
''';
}
