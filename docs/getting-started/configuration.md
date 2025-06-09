## 🔧 Configuration Options

### Environment Variables (`.env`)

```bash
# will be used for direct connections to the dart vm
DART_VM_PORT=8181
DART_VM_HOST=localhost

# will be used for this MCP server
MCP_SERVER_PORT=3535
MCP_SERVER_HOST=localhost

# Logging configuration
LOG_LEVEL=critical

# Development configuration
NODE_ENV=development

# Resources configuration
RESOURCES_SUPPORTED=true
```

### Command Line Arguments

```bash
--port, -p     # Server port
--stdio        # Run in stdio mode (default: true)
--resources    # Enable resources support (default: true)
--log-level    # Set logging level (debug, info, notice, warning, error, critical, alert, emergency) according to https://spec.modelcontextprotocol.io/specification/2025-03-26/server/utilities/logging/#log-levels
--help         # Show help
```

## Port Configuration

All Flutter Inspector tools automatically connect to the default Flutter debug port (8181). You only need to specify a port if:

- You're running Flutter on a different port
- You have multiple Flutter instances running
- You've configured a custom debug port

Example usage:

```json
// Default port (8181)
{
  "name": "debug_dump_render_tree"
}

// Custom port
{
  "name": "debug_dump_render_tree",
  "arguments": {
    "port": 8182
  }
}
```
