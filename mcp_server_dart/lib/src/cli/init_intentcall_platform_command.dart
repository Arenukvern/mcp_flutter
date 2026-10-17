import 'package:flutter_mcp_toolkit_server/src/cli/intentcall_delegate.dart';

/// `flutter-mcp-toolkit init intentcall-platform` delegates to the
/// IntentCall CLI, discovered at runtime (ADR-0016). [cli] overrides
/// resolution (tests inject a fake).
Future<int> runInitintentcallPlatform({
  required String projectRoot,
  bool checkOnly = false,
  IntentcallCli? cli,
}) => delegatePlatformHooksInit(
  projectRoot: projectRoot,
  checkOnly: checkOnly,
  cli: cli,
);
