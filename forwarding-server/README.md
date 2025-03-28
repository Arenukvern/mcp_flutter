# Forwarding Server

This package is a part of the [Flutter MCP](https://github.com/Arenukvern/mcp_flutter).

A WebSocket forwarding server that enables bi-directional communication between Flutter applications and TypeScript clients.

## Overview

This package provides a standalone WebSocket server that can:

- Accept connections from both Flutter and TypeScript clients
- Forward messages between different client types
- Prevent message loops by tracking forwarded messages
- Emit events for client connections/disconnections

## Installation

```bash
npm install
```

## Usage

### Starting the Server

```bash
# Start with default settings (port 8143, path /forward)
npm start

# Start with custom port
npm start -- --port 9000

# Start with custom WebSocket path
npm start -- --path /ws

# Show help
npm start -- --help
```

### Environment Variables

You can also configure the server using environment variables:

- `FORWARDING_SERVER_PORT`: Port to run the server on (default: 8143)
- `FORWARDING_SERVER_PATH`: WebSocket path (default: /forward)

### Connecting Clients

Connect to the WebSocket server with the appropriate client type:

```
ws://localhost:8143/forward?clientType=flutter    # For Flutter clients
ws://localhost:8143/forward?clientType=inspector  # For TypeScript/Inspector clients
```

## Development

```bash
# Install dependencies
npm install

# Build the project
npm run build

# Run in development mode (with auto-reload)
npm run dev

# Lint the project
npm run lint
```

## API

The server works by accepting WebSocket connections and forwarding messages between client types.

### Client Types

- `flutter`: For connections from Flutter applications
- `inspector`: For connections from TypeScript/Inspector applications

### Message Forwarding

All messages received from one client type are forwarded to all connected clients of the other type.

The server handles JSON-RPC 2.0 formatted messages, tracking message IDs to prevent circular forwarding.

## Architecture

```
+----------------+                  +-------------------+
|                |                  |                   |
| Flutter Client +<---------------->+ Forwarding Server |
|                |                  |                   |
+----------------+                  |                   |
                                    |                   |
+----------------+                  |                   |
|                |                  |                   |
| Inspector Client +<--------------->+                   |
|                |                  |                   |
+----------------+                  +-------------------+
```
