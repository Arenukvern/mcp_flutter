#!/bin/bash

# Flutter Inspector MCP Server - Cursor Setup Script
# This script automates the setup process for Cursor MCP integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MCP_SERVER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../mcp_server_dart" && pwd)"
EXECUTABLE_NAME="flutter_inspector_mcp"
DEFAULT_PORT="8181"
DEFAULT_HOST="localhost"

echo -e "${BLUE}🚀 Flutter Inspector MCP Server - Cursor Setup${NC}"
echo "=================================================="

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v dart &> /dev/null; then
    echo -e "${RED}❌ Dart SDK not found. Please install Dart SDK first.${NC}"
    exit 1
fi

if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter SDK not found. Please install Flutter SDK first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Build the executable
echo -e "${YELLOW}Building MCP server executable...${NC}"
cd "$MCP_SERVER_DIR"

if dart compile exe bin/flutter_mcp_toolkit_server.dart -o "$EXECUTABLE_NAME"; then
    chmod +x "$EXECUTABLE_NAME"
    echo -e "${GREEN}✅ Executable built successfully: $MCP_SERVER_DIR/$EXECUTABLE_NAME${NC}"
else
    echo -e "${RED}❌ Failed to build executable${NC}"
    exit 1
fi

# Get configuration preferences
echo -e "${YELLOW}Configuration setup...${NC}"

read -p "Enter Dart VM host (default: $DEFAULT_HOST): " VM_HOST
VM_HOST=${VM_HOST:-$DEFAULT_HOST}

read -p "Enter Dart VM port (default: $DEFAULT_PORT): " VM_PORT
VM_PORT=${VM_PORT:-$DEFAULT_PORT}

read -p "Enable resources support? (y/n, default: y): " ENABLE_RESOURCES
ENABLE_RESOURCES=${ENABLE_RESOURCES:-y}

read -p "Enable images support? (y/n, default: y): " ENABLE_IMAGES
ENABLE_IMAGES=${ENABLE_IMAGES:-y}

# Determine Cursor config location
CURSOR_CONFIG_DIR="$HOME/.cursor"
PROJECT_CONFIG_DIR=".cursor"

echo -e "${YELLOW}Where would you like to install the configuration?${NC}"
echo "1) Global (~/.cursor/mcp_servers.json)"
echo "2) Project-specific (.cursor/mcp_servers.json)"
echo "3) Both"

read -p "Choose option (1-3, default: 1): " CONFIG_CHOICE
CONFIG_CHOICE=${CONFIG_CHOICE:-1}

# Build configuration JSON
EXECUTABLE_PATH="$MCP_SERVER_DIR/$EXECUTABLE_NAME"
ARGS="[\"--dart-vm-host=$VM_HOST\", \"--dart-vm-port=$VM_PORT\""

if [[ "$ENABLE_RESOURCES" =~ ^[Yy]$ ]]; then
    ARGS="$ARGS, \"--resources-supported\""
fi

if [[ "$ENABLE_IMAGES" =~ ^[Yy]$ ]]; then
    ARGS="$ARGS, \"--images-supported\""
fi

ARGS="$ARGS]"

CONFIG_JSON=$(cat <<EOF
{
  "mcpServers": {
    "flutter-inspector": {
      "command": "$EXECUTABLE_PATH",
      "args": $ARGS,
      "env": {}
    }
  }
}
EOF
)

# Function to write config
write_config() {
    local config_dir="$1"
    local config_file="$config_dir/mcp_servers.json"
    
    mkdir -p "$config_dir"
    
    if [[ -f "$config_file" ]]; then
        echo -e "${YELLOW}⚠️  Configuration file already exists: $config_file${NC}"
        read -p "Overwrite? (y/n): " OVERWRITE
        if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Skipping $config_file${NC}"
            return
        fi
    fi
    
    echo "$CONFIG_JSON" > "$config_file"
    echo -e "${GREEN}✅ Configuration written to: $config_file${NC}"
}

# Write configuration based on choice
case $CONFIG_CHOICE in
    1)
        write_config "$CURSOR_CONFIG_DIR"
        ;;
    2)
        write_config "$PROJECT_CONFIG_DIR"
        ;;
    3)
        write_config "$CURSOR_CONFIG_DIR"
        write_config "$PROJECT_CONFIG_DIR"
        ;;
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac

# Test the setup
echo -e "${YELLOW}Testing the setup...${NC}"

if "$EXECUTABLE_PATH" --help > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Executable test passed${NC}"
else
    echo -e "${RED}❌ Executable test failed${NC}"
    exit 1
fi

# Final instructions
echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Start your Flutter app in debug mode:"
echo "   ${YELLOW}flutter run --debug${NC}"
echo ""
echo "2. Restart Cursor IDE to load the new MCP configuration"
echo ""
echo "3. Test the integration by asking Cursor:"
echo "   ${YELLOW}\"Hot reload my Flutter app\"${NC}"
echo ""
echo -e "${BLUE}Available commands in Cursor:${NC}"
echo "• Hot reload my Flutter app"
echo "• Get VM information"
echo "• Show me app screenshots"
echo "• What are the latest errors?"
echo "• List extension RPCs"
echo ""
echo -e "${BLUE}Configuration details:${NC}"
echo "• Executable: $EXECUTABLE_PATH"
echo "• VM Host: $VM_HOST"
echo "• VM Port: $VM_PORT"
echo "• Resources: $([ "$ENABLE_RESOURCES" = "y" ] && echo "Enabled" || echo "Disabled")"
echo "• Images: $([ "$ENABLE_IMAGES" = "y" ] && echo "Enabled" || echo "Disabled")"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "• Ensure Flutter app is running on port $VM_PORT"
echo "• Check Cursor logs if MCP server doesn't connect"
echo "• Verify executable permissions: chmod +x $EXECUTABLE_PATH"
echo ""
echo -e "${BLUE}For more help, see: docs/cursor_mcp_integration.md${NC}" 