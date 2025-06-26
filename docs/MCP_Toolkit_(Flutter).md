# API Reference: MCP Toolkit (Flutter)

This page provides a reference for the public API of the `mcp_toolkit` package.

### `MCPToolkitBinding`

The singleton class that manages the connection to the MCP server and the registration of tools.

- **`MCPToolkitBinding.instance`**: The singleton instance of the binding.
- **`initialize()`**: Initializes the binding.
- **`addMcpTool(MCPCallEntry entry)`**: Registers a single tool.
- **`addEntries({required Set<MCPCallEntry> entries})`**: Registers a set of tools.

### `MCPCallEntry`

A class that represents a tool or resource that can be called by the MCP server.

- **`MCPCallEntry.tool(...)`**: Creates a new tool entry.
- **`MCPCallEntry.resource(...)`**: Creates a new resource entry.

### `MCPCallResult`

A class that represents the result of a tool or resource call.
