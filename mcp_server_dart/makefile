setup:
	flutter pub get && make compile
compile: 
	dart compile exe bin/main.dart -o build/flutter_inspector_mcp
inspect:
	npx @modelcontextprotocol/inspector build/flutter_inspector_mcp

# Flutter Inspector MCP Server - Dart Implementation

# Run the MCP server in development mode with simplified discovery
.PHONY: run-simplified
run-simplified:
	@echo "🚀 Starting MCP Server with Simplified Discovery..."
	@echo "📝 This will automatically discover Flutter apps when VM service connects"
	DYNAMIC_REGISTRY_SUPPORTED=true \
	LOG_LEVEL=debug \
	dart run bin/flutter_inspector_mcp_server.dart

# Test the simplified discovery with a Flutter app
.PHONY: test-discovery
test-discovery:
	@echo "🧪 Testing Simplified Discovery System..."
	@echo "1. Starting MCP server in background..."
	@DYNAMIC_REGISTRY_SUPPORTED=true LOG_LEVEL=info dart run bin/flutter_inspector_mcp_server.dart &
	@echo "2. Waiting for server startup..."
	@sleep 3
	@echo "3. Now run your Flutter app with MCP toolkit to see automatic discovery!"
	@echo "   Example: cd ../mcp_toolkit/mcp_toolkit/example && flutter run fibonacci_tool_example.dart"
	@echo "4. Tools should appear immediately when the Flutter app starts"

# Clean up any background processes
.PHONY: cleanup
cleanup:
	@echo "🧹 Cleaning up background processes..."
	@pkill -f flutter_inspector_mcp_server || true
	@echo "✅ Cleanup complete"

# Show help for the simplified system
.PHONY: help-simplified
help-simplified:
	@echo "📚 Simplified Dynamic Registration System"
	@echo ""
	@echo "Key Benefits:"
	@echo "  ✅ Immediate tool registration (no polling)"
	@echo "  ✅ Event-driven updates via DTD"
	@echo "  ✅ Single isolate simplicity"
	@echo "  ✅ Hot reload support"
	@echo ""
	@echo "Available targets:"
	@echo "  make run-simplified    - Start server with simplified discovery"
	@echo "  make test-discovery    - Test the discovery system"
	@echo "  make cleanup          - Clean up background processes"
	@echo ""
	@echo "Usage:"
	@echo "  1. Run 'make run-simplified' in one terminal"
	@echo "  2. Start your Flutter app with MCP toolkit in another terminal"
	@echo "  3. Tools should appear immediately!"

.PHONY: help
help: help-simplified