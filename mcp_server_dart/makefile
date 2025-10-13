.PHONY: setup
setup:
	flutter pub get && make compile

.PHONY: compile
compile:
	@ mkdir -p build && \
	dart compile exe bin/main.dart -o build/flutter_inspector_mcp

.PHONY: inspect
inspect:
	npx @modelcontextprotocol/inspector build/flutter_inspector_mcp --log-level=debug

.PHONY: inspect-verbose
inspect-verbose:
	npx @modelcontextprotocol/inspector build/flutter_inspector_mcp --log-level=debug --verbose

# Clean up any background processes
.PHONY: cleanup
cleanup:
	@echo "🧹 Cleaning up background processes..."
	@pkill -f flutter_inspector_mcp_server || true
	@echo "✅ Cleanup complete"

# Docker targets
.PHONY: docker-build
docker-build:
	@echo "🐳 Building production Docker image..."
	docker build -t mcp_server:latest .
	@echo "✅ Build complete"

.PHONY: docker-build-dev
docker-build-dev:
	@echo "🐳 Building development Docker image..."
	docker build -f Dockerfile.dev -t mcp_server:dev .
	@echo "✅ Build complete"

.PHONY: docker-run
docker-run:
	@echo "🚀 Running production Docker container..."
	docker run -i mcp_server:latest

.PHONY: docker-run-dev
docker-run-dev:
	@echo "🚀 Running development Docker container..."
	docker run -i mcp_server:dev

.PHONY: docker-clean
docker-clean:
	@echo "🧹 Cleaning Docker images..."
	docker rmi mcp_server:latest mcp_server:dev || true
	@echo "✅ Cleanup complete"

.PHONY: docker-help
docker-help:
	@echo "Docker targets:"
	@echo "  make docker-build       - Build production image"
	@echo "  make docker-build-dev   - Build development image"
	@echo "  make docker-run         - Run production container"
	@echo "  make docker-run-dev     - Run development container"
	@echo "  make docker-clean       - Remove Docker images"
	@echo ""
	@echo "For more details, see DOCKER.md"
