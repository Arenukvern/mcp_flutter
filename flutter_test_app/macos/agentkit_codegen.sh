# agentkit-platform: begin
cd "${SRCROOT}/.."
flutter-mcp-toolkit codegen sync --platform ios,macos || exit 1
# agentkit-platform: end
