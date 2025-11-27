# Web Platform Setup Checklist

This checklist ensures proper setup for Flutter Web MCP integration.

## ✅ Pre-Installation

- [ ] Flutter SDK installed (3.0.0 or later)
- [ ] `fvm` installed (if using Flutter Version Manager)
- [ ] MCP server repository cloned
- [ ] MCP server compiled successfully

## ✅ MCP Server Configuration

- [ ] MCP server executable built: `mcp_server_dart/build/flutter_inspector_mcp.exe` (Windows) or `mcp_server_dart/build/flutter_inspector_mcp` (Linux/macOS)
- [ ] MCP server configured in AI assistant (Cursor, Claude, etc.)
- [ ] MCP server path includes `build/` directory and `.exe` extension (Windows)
- [ ] MCP server restarted after compilation

## ✅ Flutter App Setup

- [ ] `mcp_toolkit` package added to `pubspec.yaml`
- [ ] `flutter pub get` executed successfully
- [ ] `main.dart` includes platform check: `if (kIsWeb)`
- [ ] Web initialization uses: `initializeWebBridgeForWeb(bridgeUrl: 'ws://localhost:8183')`
- [ ] `initializeFlutterToolkit()` called after web bridge initialization
- [ ] Error handling with `runZonedGuarded` implemented

## ✅ Running the App

- [ ] App started with: `flutter run -d chrome --web-port=8080`
- [ ] App is running in debug mode
- [ ] Waited 30-40 seconds after app start for connection
- [ ] Web bridge connection verified (check MCP server logs)

## ✅ Verification

- [ ] MCP server logs show "Web bridge server started on port 8183"
- [ ] MCP server logs show "Web client connected" when app starts
- [ ] `listClientToolsAndResources` returns tools (after connection established)
- [ ] `get_screenshots` works successfully
- [ ] `get_app_errors` works successfully
- [ ] `get_view_details` works successfully

## 🔍 Troubleshooting

If tools return "VM service not connected and no web clients available":

1. **Check MCP Server:**
   - Verify web bridge is running: `netstat -ano | findstr 8183` (Windows) or `lsof -i :8183` (macOS/Linux)
   - Check MCP server logs for "Web bridge server started"
   - Restart MCP server if needed

2. **Check Flutter App:**
   - Verify `initializeWebBridgeForWeb()` is called in `main.dart`
   - Check browser console for WebSocket connection errors
   - Ensure app is running: `flutter run -d chrome --web-port=8080`

3. **Check Connection:**
   - Wait 30-40 seconds after starting the app
   - Verify both are on localhost
   - Check firewall settings

4. **Common Issues:**
   - Missing `kIsWeb` check in `main.dart` → Add platform check
   - Wrong bridge URL (must be `ws://localhost:8183`)
   - MCP server not restarted after code changes
   - App not waiting long enough for connection

## 📝 Code Template

Use this template in your `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'dart:async';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      
      // CRITICAL: Platform-specific initialization
      if (kIsWeb) {
        // For Flutter Web: use WebSocket bridge (port 8183)
        await MCPToolkitBinding.instance.initializeWebBridgeForWeb(
          bridgeUrl: 'ws://localhost:8183',
        );
        MCPToolkitBinding.instance.initializeFlutterToolkit();
      } else {
        // For Mobile/Desktop: use VM Service (port 8181)
        MCPToolkitBinding.instance
          ..initialize()
          ..initializeFlutterToolkit();
      }
      
      runApp(const MyApp());
    },
    (error, stack) {
      MCPToolkitBinding.instance.handleZoneError(error, stack);
    },
  );
}
```


