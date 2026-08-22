# Docker Deployment Guide

This guide covers building and running the MCP Server using Docker.

## Install from GHCR (MCP Registry image)

The official MCP Registry image is published to GHCR on every release:

```bash
docker pull ghcr.io/arenukvern/flutter-mcp-toolkit:latest
```

Use it in an `mcpServers` config:

```json
{
  "mcpServers": {
    "flutter-mcp-toolkit": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "--network=host",
        "ghcr.io/arenukvern/flutter-mcp-toolkit:latest"
      ]
    }
  }
}
```

> `--network=host` is required on macOS/Linux so the container can reach the
> Dart VM service of your locally running Flutter debug app. Pin a specific
> version tag (for example `ghcr.io/arenukvern/flutter-mcp-toolkit:4.0.0-dev.8`)
> instead of `latest` for reproducible setups.

## Overview

Two Dockerfiles are provided:

- **`Dockerfile`** - Production-ready, multi-stage build with compiled binary
- **`Dockerfile.dev`** - Development version with Dart VM for debugging
- **`Dockerfile.registry`** - Dedicated GHCR/MCP Registry image with Registry ownership metadata

The first two files preserve the existing local Docker contract. The Registry
workflow uses `Dockerfile.registry` and does not change local Docker builds.

## Production Deployment

### Build

```bash
# Build the production image
docker build -t mcp_server:latest .

# Build with specific version tag
docker build -t mcp_server:0.1.0 .
```

### Run

```bash
# Run with default settings
docker run -i mcp_server:latest

# Run with custom arguments
docker run -i mcp_server:latest \
  --resources \
  --images \
  --dumps \
  --log-level=info

# Run with environment override
docker run -i mcp_server:latest \
  --environment=development \
  --log-level=debug
```

### Key Features

- **Multi-stage build**: Smaller final image (~50MB vs ~200MB)
- **Compiled binary**: Better performance, faster startup
- **Non-root user**: Enhanced security (UID 1001)
- **Signal handling**: Proper process management with tini
- **Layer caching**: Optimized for faster rebuilds

## Development Deployment

### Build

```bash
# Build the development image
docker build -f Dockerfile.dev -t mcp_server:dev .
```

### Run

```bash
# Run with debug logging
docker run -i mcp_server:dev

# Run with custom arguments
docker run -i mcp_server:dev \
  dart run bin/main.dart --resources --images --log-level=debug
```

### Key Features

- **No compilation**: Faster build times
- **Dart VM**: Better error messages and debugging
- **Debug mode**: Default log level is debug
- **Hot reload**: Easier iteration (mount volumes)

## Docker Compose

Create `docker-compose.yml`:

```yaml
version: "3.8"

services:
  mcp_server:
    build:
      context: .
      dockerfile: Dockerfile
    image: mcp_server:latest
    stdin_open: true
    restart: unless-stopped
    command:
      - --resources
      - --images
      - --log-level=info

  mcp_server_dev:
    build:
      context: .
      dockerfile: Dockerfile.dev
    image: mcp_server:dev
    stdin_open: true
    volumes:
      - ./bin:/app/bin
      - ./lib:/app/lib
    command:
      - dart
      - run
      - bin/main.dart
      - --resources
      - --images
      - --log-level=debug
```

Run with:

```bash
# Production
docker-compose up mcp_server

# Development
docker-compose up mcp_server_dev
```

## Important Notes

### MCP Protocol Communication

- MCP servers use **stdio** (stdin/stdout), not network ports
- No HTTP/TCP endpoints are exposed
- Communication happens via JSON-RPC over stdio streams
- The `--dart-vm-port=8181` flag is for connecting TO a Flutter app, not serving FROM this container

### Connecting to Flutter Apps

To connect to a Flutter app from the containerized MCP server:

```bash
# App must be accessible from container network
docker run -i \
  --network=host \
  mcp_server:latest \
  --dart-vm-host=localhost \
  --dart-vm-port=8181
```

Or use Docker networking:

```bash
docker network create mcp_network

# Run Flutter app container (if applicable)
docker run --network=mcp_network --name flutter_app ...

# Run MCP server
docker run -i \
  --network=mcp_network \
  mcp_server:latest \
  --dart-vm-host=flutter_app \
  --dart-vm-port=8181
```

## Available Arguments

All Dockerfile CMD arguments can be overridden:

| Argument         | Default      | Description                         |
| ---------------- | ------------ | ----------------------------------- |
| `--dart-vm-host` | `localhost`  | Flutter VM host                     |
| `--dart-vm-port` | `8181`       | Flutter VM port                     |
| `--resources`    | `true`       | Enable resources support            |
| `--images`       | `true`       | Enable images support               |
| `--dumps`        | `false`      | Enable debug dumps                  |
| `--dynamics`     | `true`       | Enable dynamic registry             |
| `--await-dnd`    | `false`      | Wait for DND connection             |
| `--save-images`  | `false`      | Save images as files                |
| `--log-level`    | `error`      | Log level (debug\|info\|error\|etc) |
| `--environment`  | `production` | Environment mode                    |

### Best Practices

```bash
# Run with read-only root filesystem
docker run -i --read-only mcp_server:latest

# Limit resources
docker run -i \
  --memory=256m \
  --cpus=0.5 \
  mcp_server:latest

# Drop capabilities
docker run -i \
  --cap-drop=ALL \
  mcp_server:latest
```

## Troubleshooting

### Build Fails

```bash
# Check Dart SDK version
docker run dart:3.12.0-sdk dart --version

# Clean build
docker build --no-cache -t mcp_server:latest .
```

### Runtime Issues

```bash
# Check logs
docker logs <container_id>

# Run with debug logging
docker run -i mcp_server:latest --log-level=debug

# Interactive debugging
docker run -it --entrypoint=/bin/bash mcp_server:latest
```

### Performance Issues

```bash
# Use compiled version (Dockerfile, not Dockerfile.dev)
docker build -t mcp_server:latest .

# Profile memory usage
docker stats <container_id>
```

## Registry Publishing

The official image is built from `Dockerfile.registry` and published to GHCR by
[`.github/workflows/publish_mcp_registry.yml`](../.github/workflows/publish_mcp_registry.yml)
when `pub_publish.yml` completes. Manual local build:

```bash
docker build -f Dockerfile.registry -t flutter-mcp-toolkit:registry .
```
