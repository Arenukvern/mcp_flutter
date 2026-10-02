import 'package:flutter_mcp_toolkit_server/src/cli/intentcall_delegate.dart';

/// `flutter-mcp-toolkit init intentcall-platform` delegates to the
/// IntentCall CLI, discovered at runtime (ADR-0016). [cli] overrides
/// resolution (tests inject a fake).
Future<int> runInitintentcallPlatform({
  required final String projectRoot,
  final bool checkOnly = false,
  final IntentcallCli? cli,
}) => delegatePlatformHooksInit(
  projectRoot: projectRoot,
  checkOnly: checkOnly,
  cli: cli,
);
