## 0.2.0

- Added `addMcpTool` function to add a single MCP tool to the MCP toolkit.

## BREAKING CHANGES

- Replaced `MCPCallEntry` with two constructors to create MCPCallEntry for resources and tools:
  - `MCPCallEntry.resource` to create MCPCallEntry for resources.
  - `MCPCallEntry.tool` to create MCPCallEntry for tools.
    This change simplifies the syntax by removing the need to write name of tool twice.

## 0.1.2

- Added `kDefaultMaxErrors` and `maxErrors` constants to `ErrorMonitor` class to limit number of errors stored.
- Added `kDebugMode` check to `MCPToolkitBinding.initialize` method.
- Added `kDebugMode` check to `MCPToolkitExtensions.initializeServiceExtensions` method.
- Added `kDebugMode` check to `MCPToolkitExtensions.registerServiceExtension` method to prevent adding entries in release mode.

## 0.1.1

- Fixed documentation.

## 0.1.0

- Initial release.
