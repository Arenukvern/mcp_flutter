# Flutter Inspector Architecture

## Quick Start

- [Installation Guide](README.md#quick-start)
- [API Documentation](README.md#learn-more)
- [Contributing Guidelines](README.md#contributing)

## System Overview

This project enables AI-powered development tools to interact with Flutter applications through two distinct communication paths:

### 1. Direct VM Service Communication

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│                 │         │                  │         │                 │
│  Flutter App    │<------->│    Dart VM       │<------->│   MCP Server   │
│  (Debug Mode)   │         │    Service       │         │                 │
│                 │         │    (Port 8181)   │         │                 │
└─────────────────┘         └──────────────────┘         └─────────────────┘
```

Used for: Basic VM operations, general Dart runtime inspection

### 2. Flutter-Specific Communication

```
┌─────────────────┐     ┌──────────────┐     ┌──────────────┐     ┌─────────────────┐
│                 │     │              │     │              │     │                 │
│  Flutter App    │<--->│  DevTools    │<--->│  Forwarding  │<--->│   MCP Server   │
│  (Debug Mode)   │     │  Extension   │     │  Server      │     │                 │
│                 │     │              │     │              │     │                 │
└─────────────────┘     └──────────────┘     └──────────────┘     └─────────────────┘
```

Used for: Flutter-specific operations (widget inspection, layout analysis, etc.)

### When to Use This

1. **Direct VM Service Communication**:

   - Memory inspection
   - Basic debugging operations
   - Isolate management
   - General VM state queries

2. **Flutter-Specific Operations** (via Forwarding Server):
   - Widget tree inspection
   - Layout debugging
   - State management analysis
   - Performance profiling
   - UI element interaction

## Architecture Components

### 1. Flutter Application Layer

**Location**: Your Flutter App
**Purpose**: Debug target application
**Requirements**:

- Must run in debug mode
- DevTools MCP Extension installed
- Port 8181 available for VM Service

### 2. DevTools MCP Extension Layer

**Location**: `devtools_mcp_extension/`
**Purpose**: Bridge between Flutter and MCP
**Key Features**:

- VM Service Protocol integration
- Real-time widget tree access
- State management hooks
- Performance metrics collection

### 3. MCP Server Layer

**Location**: `mcp_server/`
**Purpose**: Protocol translation and request handling
**Key Features**:

- JSON-RPC to VM Service Protocol translation
- Request routing and validation
- Error handling and logging
- Connection management

### 4. AI Assistant Integration Layer

**Location**: AI Tool (e.g., Cline, Claude, Cursor)
**Purpose**: Developer interaction and analysis
**Features**:

- Code analysis and suggestions
- Widget tree visualization
- Debug information display
- Performance recommendations

## Communication Flow

1. **Request Initiation**:

   ```
   AI Assistant -> MCP JSON-RPC Request -> MCP Server
   ```

2. **Protocol Translation**:

   ```
   MCP Server -> VM Service Protocol -> DevTools Extension
   ```

3. **Flutter Interaction**:

   ```
   DevTools Extension -> VM Service -> Flutter App
   ```

4. **Response Flow**:
   ```
   Flutter App -> DevTools Extension -> MCP Server -> AI Assistant
   ```

## Protocol Details

### 1. MCP (Model Context Protocol)

- JSON-RPC 2.0 based
- Standardized message format
- Type-safe interactions
- Extensible command system

### 2. VM Service Protocol

- Flutter's native debugging protocol
- Real-time state access
- Widget tree manipulation
- Performance metrics collection

## Security Considerations

1. **Debug Mode Only**:

   - All operations require debug mode
   - No production access
   - Controlled environment execution

2. **Port Security**:

   - Default ports: 8181 (VM), 8182 (MCP)
   - Local-only connections
   - Port validation and verification

3. **Data Safety**:

   - No sensitive data exposure
   - Sanitized error messages
   - Controlled access scope

## Performance Optimization

1. **Connection Management**:

   - Connection pooling
   - Automatic reconnection
   - Resource cleanup

2. **Data Efficiency**:

   - Response caching
   - Batch operations
   - Optimized protocol translation

3. **Error Handling**:
   - Graceful degradation
   - Detailed error reporting
   - Recovery mechanisms

## Extension Points

### 1. Custom Commands

```typescript
// Add new commands in server_tools_handler.yaml
handlers:
  - name: custom_command
    description: Your custom functionality
    rpcMethod: "ext.flutter.custom"
```

### 2. Protocol Extensions

```dart
// Implement custom protocol handlers
class CustomProtocolHandler {
  Future<Response> handleCustomMethod(Request request) {
    // Your custom logic
  }
}
```

## Common Use Cases

1. **Widget Analysis**:

   ```typescript
   // Example: Get widget tree
   const widgetTree = await inspector.getRootWidget();
   ```

2. **Layout Debugging**:

   ```typescript
   // Example: Analyze layout issues
   const layoutInfo = await inspector.debugDumpRenderTree();
   ```

3. **Performance Profiling**:
   ```typescript
   // Example: Profile widget builds
   await inspector.profileWidgetBuilds({ enabled: true });
   ```

## Troubleshooting

1. **Connection Issues**:

   - Verify debug mode is active
   - Check port availability
   - Confirm extension installation

2. **Protocol Errors**:

   - Validate message format
   - Check method availability
   - Verify parameter types

3. **Performance Problems**:
   - Monitor message volume
   - Check response times
   - Analyze resource usage

## Further Reading

- [Flutter DevTools Documentation](https://docs.flutter.dev/development/tools/devtools/overview)
- [VM Service Protocol](https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md)
- [MCP Protocol Specification](https://modelcontextprotocol.io/introduction)
