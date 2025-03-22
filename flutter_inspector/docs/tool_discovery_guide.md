# Flutter Inspector Tool Discovery Guide

## Overview

This guide explains how to discover available Flutter RPC methods and implement them as tools in the Flutter Inspector.

## Discovery Process

1. **Identify Available RPCs**

   - Connect to a running Flutter app in debug mode
   - Use `get_extension_rpcs` tool to retrieve all available RPCs:
     ```typescript
     // Example: Get all extension RPCs from port 8181
     mcp_flutter_inspector_get_extension_rpcs();
     ```
   - The response contains a list of all available extension methods (`ext.*`)

2. **Analyze RPC Method Signatures**

   - For each method, identify:
     - Method name (e.g., `ext.flutter.debugDumpRenderTree`)
     - Required parameters
     - Return type and structure

3. **Test RPC Methods Directly**
   - Use Dart VM Service Protocol to call methods directly
   - Analyze responses to understand parameter requirements

## Implementation Steps

1. **Add Tool Definition**

   - Add entry to `server_tools_flutter.yaml` with:
     - Appropriate tool name using prefix convention
     - JSONSchema for parameters
     - Clear description

2. **Add Handler Implementation**

   - Add entry to `server_tools_handler.yaml` with:
     - Matching tool name
     - Correct `rpcMethod` value (exact method name)
     - Appropriate `needsDartServiceExtensionProxy` setting

3. **Generate Handler Code**

   - Run `npm run generate-rpc-handlers`
   - Verify generated TypeScript handlers in:
     - `src/servers/flutter_rpc_handlers.generated.ts`
     - `src/servers/create_rpc_handler_map.generated.ts`

4. **Test New Tool**
   - Connect to a Flutter app in debug mode
   - Call the new tool with appropriate parameters
   - Verify response format and content

## Categorizing Discovered Methods

When discovering new methods, categorize them based on:

1. **Functionality Type**

   - Debugging visualization: Use `debug_*` prefix
   - Widget inspection: Use `inspector_*` prefix
   - Dart I/O operations: Use `dart_io_*` prefix
   - Core Flutter operations: Use `flutter_core_*` prefix

2. **Parameter Requirements**

   - Simple toggles: Use `enabled` parameter
   - Widget identification: Use `objectId` parameter
   - Platform-specific: Use enumerated values

3. **Proxy Requirements**
   - Any method starting with `ext.flutter.inspector.*` requires proxy
   - Most other methods can use direct VM service communication

## Resources

- [Flutter DevTools Protocol](https://github.com/flutter/flutter/wiki/VM-Service-Protocol)
- [VM Service Protocol](https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md)
- [Flutter Inspector Internal Architecture](./handler_generation_guide.md)
- [Adding New Tools Guide](./tool_addition_guide.md)
