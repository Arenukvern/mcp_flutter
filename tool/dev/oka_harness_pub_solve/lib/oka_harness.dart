/// Device E2E targets over oka's owning dev sessions (ADR-0026).
///
/// oka owns compile/sync and process lifecycle; the MCP toolkit is the
/// observation oracle (oka ADR-0024, mcp_flutter ADR-0014). This package is
/// the bridge: [AndroidAppTarget] starts `oka dev` — the owning session that
/// builds, installs, launches, and attaches — and hands the harness core
/// ([flutter_mcp_harness](https://pub.dev/packages/flutter_mcp_harness)) a
/// [LaunchedApp] wired to the forwarded VM service URI published in
/// `.flutter_mcp/runner-session.json`.
///
/// Scenarios then drive/assert with `ToolkitDriver`/`Scenario` exactly like
/// desktop targets do; `example/` shows the composition root.
library;

export 'src/android_app_target.dart';
export 'src/ios_simulator_app_target.dart';
export 'src/session_composition.dart';
