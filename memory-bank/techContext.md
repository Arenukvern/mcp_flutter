# Tech Context

**Technologies:** Flutter, Dart, JSON-RPC, VM Service Protocol, WebSockets.

**Development Setup:** Requires Dart/Flutter SDK, a Flutter app running in debug mode with `mcp_toolkit`, and an AI assistant (Cursor, Claude, or Cline).

**Dependencies:**

- Flutter/Dart: `mcp_server_dart`, `mcp_toolkit`, `vm_service`, `web_socket_channel`

## VM Service Protocol

**Core Services:**

- VM Service Interface: Provides access to VM internals and debugging capabilities
- Error Handling: Diagnostic information about Flutter application and its error state
- Object Management: Reference tracking and memory management for Flutter application

**Flutter Application Error Structure:**

```dart
class NodeErrorInfo {
  final String nodeId;
  final String errorMessage;
  // Additional diagnostic properties
}
```

## Flutter Application Error Handling

**Access Patterns:**

- VM Service queries for error states
- Diagnostic node property inspection
- Error monitoring and notification system
