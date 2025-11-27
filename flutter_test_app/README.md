# Flutter Test App - MCP Toolkit Demo

This Flutter app demonstrates the MCP Toolkit integration with support for both mobile/desktop and web platforms.

## Features

- Dynamic MCP tool registration
- Flutter service extensions
- Error monitoring
- State management examples
- **Web support via WebSocket bridge**

## Running the App

### Mobile/Desktop (iOS, Android, Windows, macOS, Linux)

```bash
flutter run --debug --host-vmservice-port=8182 --dds-port=8181 --enable-vm-service --disable-service-auth-codes
```

### Web

```bash
flutter run -d chrome --web-port=8080
```

The app automatically detects if it's running on web and uses the WebSocket bridge (port 8183) instead of the VM Service.

## MCP Server Setup

Make sure the MCP server is running and configured in your AI assistant (Cursor, Claude, etc.). The web bridge server starts automatically on port 8183 when the MCP server initializes.

## Architecture

- **Mobile/Desktop**: Uses Dart VM Service (port 8181)
- **Web**: Uses WebSocket Bridge (port 8183) for communication

## Web Platform Limitations

Flutter Web doesn't expose the Dart VM Service, so some MCP tools are not available:

**✅ Available Tools:**
- `get_app_errors` - Get application errors
- `get_screenshots` - Capture screenshots
- `get_view_details` - Get view information
- `get_active_ports` - List active ports
- `listClientToolsAndResources` - Dynamic tools discovery (when web client is connected)

**❌ Not Available (require VM Service):**
- `get_vm` - VM information
- `get_extension_rpcs` - Extension RPCs
- `hot_reload_flutter` - Hot reload (requires VM Service; Flutter Web supports hot reload but only via DevTools/terminal)
- `hot_restart_flutter` - Hot restart

**Important Setup Requirements:**
- The app must use `initializeWebBridgeForWeb(bridgeUrl: 'ws://localhost:8183')` in `main.dart`
- The MCP server must be running (web bridge starts automatically on port 8183)
- Wait 30-40 seconds after starting the app for the connection to establish
- Both MCP server and Flutter app must be on localhost

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
