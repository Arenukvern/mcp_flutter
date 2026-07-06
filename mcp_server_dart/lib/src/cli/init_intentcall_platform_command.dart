import 'intentcall_delegate.dart';

/// `flutter-mcp-toolkit init intentcall-platform` delegates to [intentcall_cli].
Future<int> runInitintentcallPlatform({
  required final String projectRoot,
  final bool checkOnly = false,
}) {
  return delegatePlatformHooksInit(
    projectRoot: projectRoot,
    checkOnly: checkOnly,
  );
}
