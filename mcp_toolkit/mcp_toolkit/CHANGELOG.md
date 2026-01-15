# 0.4.0

- Dart SDK updated to 3.10.0 with all dependencies updated to the latest versions

- now VM service auto-reconnect when Flutter app restarts. Huge thank you to [@jkitching](https://github.com/jkitching) for PR! https://github.com/Arenukvern/mcp_flutter/pull/73

## 0.3.0

BREAKING CHANGES:

Dart SDK: 3.8.0

- chore: dart_mcp: ^0.3.30
- chore: from_json_to_json: ^0.3.0
- chore: lints: ^6.0.0
- chore: xsoulspace_lints: ^0.1.2

## 0.2.3

- perf: added more checks for [MCPCallEntry.resourceUri]

## 0.2.0

- Added `addMcpTool` function to add a single MCP tool to the MCP toolkit.

## BREAKING CHANGES

- Replaced `MCPCallEntry` with two constructors to create MCPCallEntry for resources and tools:
  - `MCPCallEntry.resource` to create MCPCallEntry for resources.
  - `MCPCallEntry.tool` to create MCPCallEntry for tools.
    This change simplifies the syntax by removing the need to write name of tool twice.
  - Now `MCPToolDefinition` has inputSchema as required parameter with `ObjectSchema` from `dart_mcp` package for better type safety. For example:
    ```dart
      definition: MCPToolDefinition(
        name: 'calculate_fibonacci',
        description: 'Calculate the nth Fibonacci number and return the sequence',
        inputSchema: ObjectSchema(
          properties: {
            'n': IntegerSchema(
              description: 'The position in the Fibonacci sequence (0-100)',
              minimum: 0,
              maximum: 100,
            ),
          },
          required: ['n'],
        ),
      ),
    ```

## 0.1.2

- Added `kDefaultMaxErrors` and `maxErrors` constants to `ErrorMonitor` class to limit number of errors stored.
- Added `kDebugMode` check to `MCPToolkitBinding.initialize` method.
- Added `kDebugMode` check to `MCPToolkitExtensions.initializeServiceExtensions` method.
- Added `kDebugMode` check to `MCPToolkitExtensions.registerServiceExtension` method to prevent adding entries in release mode.

## 0.1.1

- Fixed documentation.

## 0.1.0

- Initial release.
