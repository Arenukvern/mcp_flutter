import 'package:flutter_mcp_toolkit_server/src/cli/intentcall_delegate.dart';

/// `flutter-mcp-toolkit init intentcall-platform` delegates to [intentcall_cli].
Future<int> runInitintentcallPlatform({
  required final String projectRoot,
  final bool checkOnly = false,
}) => delegatePlatformHooksInit(projectRoot: projectRoot, checkOnly: checkOnly);
