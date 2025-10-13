# Docker Deployment Guide

IMPORTANT NOTE: Not tested - please critically review how dockerfile works before using it.

This guide covers building and running the MCP Server using Docker.

## Overview

Two Dockerfiles are provided:

- **`Dockerfile`** - Production-ready, multi-stage build with compiled binary
- **`Dockerfile.dev`** - Development version with Dart VM for debugging

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
docker run dart:3.7.0-sdk dart --version

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

```bash
# Tag for registry
docker tag mcp_server:latest myregistry.com/mcp_server:0.1.0

# Push to registry
docker push myregistry.com/mcp_server:0.1.0

# Pull and run
docker pull myregistry.com/mcp_server:0.1.0
docker run -i myregistry.com/mcp_server:0.1.0
```
