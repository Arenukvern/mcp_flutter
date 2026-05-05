// mcp_server_dart/lib/src/cli/init_mode_detector.dart
import 'package:flutter_mcp_toolkit_server/src/cli/init_mode.dart';

InitMode detectMode({
  required final bool binaryOnPath,
  required final bool mcpServerRegistered,
}) {
  if (mcpServerRegistered) return InitMode.mcp;
  if (binaryOnPath) return InitMode.cli;
  throw StateError(
    'Neither MCP server nor CLI binary detected. '
    'Install with: curl -fsSL https://raw.githubusercontent.com/Arenukvern/flutter-mcp-toolkit/main/install.sh | bash',
  );
}
