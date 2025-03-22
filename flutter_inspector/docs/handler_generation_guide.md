# Flutter Inspector Handler Generation System Guide

## Overview

The Flutter Inspector module uses a code generation system to create TypeScript handlers from YAML configuration files. The system consists of:

1. **Configuration Files**:

   - `server_tools_flutter.yaml`: Defines the tool interfaces available to users for Flutter RPC methods. These methods will be generated.
   - `server_tools_custom.yaml`: Defines the tool interfaces available to users for custom RPC methods
   - `server_tools_handler.yaml`: Maps tools to RPC method implementations

2. **Generation Scripts**:

   - `generate_rpc_handlers.ts`: Transforms YAML definitions into TypeScript handlers

3. **Generated Files**:
   - `flutter_rpc_handlers.generated.ts`: Contains the handler class with method implementations
   - `create_rpc_handler_map.generated.ts`: Maps tool names to handler methods

## Generation Process

1. The script reads `server_tools_handler.yaml` which defines handlers with:

   - `name`: Handler identifier (e.g., `debug_dump_render_tree`)
   - `description`: Human-readable description
   - `rpcMethod`: Actual Flutter/Dart method to call (e.g., `ext.flutter.debugDumpRenderTree`)
   - `needsDebugVerification`: Whether to verify the app is in debug mode
   - `needsDartServiceExtensionProxy`: Whether to use the Dart service extension proxy
   - `responseWrapper`: Whether to wrap the response in a standardized format
   - `parameters`: Mapping of user parameters to RPC parameters

2. For each handler, the script generates:

   - A TypeScript method with camelCase name (e.g., `handleDebugDumpRenderTree`)
   - Method implementation that either uses:
     - `invokeFlutterMethod` for direct VM service calls
     - `sendDartProxyRequest` for calls requiring the Dart proxy
   - Parameter handling logic based on the YAML configuration

3. Handler map generation:
   - Creates a map from tool names to handler functions
   - Handles port and parameter extraction from requests

## Key Components

1. **RpcUtilities**: Core class that provides:

   - WebSocket connections to Flutter/Dart VM service
   - Direct method invocation via `invokeFlutterMethod`
   - Proxy-based invocation via `sendDartProxyRequest`
   - Response formatting

2. **Handler Types**:

   - Regular VM service methods (e.g., `getVM`)
   - Flutter extension methods (e.g., `ext.flutter.debugDumpRenderTree`)
   - Inspector methods requiring the proxy (e.g., `ext.flutter.inspector.*`)

3. **Parameter Handling**:
   - Simple parameters passed directly
   - Structured parameters using the `arg` object
   - Port parameter handling with defaults
