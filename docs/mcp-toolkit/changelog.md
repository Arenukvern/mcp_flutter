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
