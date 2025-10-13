# Build stage
FROM dart:3.7.0-sdk AS build

WORKDIR /app

# Copy dependency files first (layer caching optimization)
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get --offline || dart pub get

# Copy source code
COPY bin/ ./bin/
COPY lib/ ./lib/
COPY analysis_options.yaml ./

# Compile to native executable for better performance and smaller image
RUN dart compile exe bin/main.dart -o /app/mcp_server

# Runtime stage - minimal image
FROM debian:bookworm-slim

# Install minimal runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    tini && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Create non-root user for security
RUN useradd -r -u 1001 -g root mcpuser

WORKDIR /app

# Copy compiled binary from build stage
COPY --from=build --chown=mcpuser:root /app/mcp_server /app/mcp_server

# Switch to non-root user
USER mcpuser

# Note: MCP servers communicate via stdio (stdin/stdout), not network ports.
# They don't expose HTTP/TCP endpoints. If you need to connect to a Flutter VM,
# that connection happens outbound from this container.

# Use tini for proper signal handling and process management
ENTRYPOINT ["/usr/bin/tini", "--", "/app/mcp_server"]

# Default arguments - can be overridden at runtime
CMD ["--resources", "--images", "--log-level=error", "--environment=production"]
