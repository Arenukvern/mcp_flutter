/// Minimal entry surface for Live Edit in a running Flutter app.
///
/// **Start here** for integration; import the full library
/// [`flutter_live_edit_toolkit`](flutter_live_edit_toolkit.dart) for commands,
/// orchestrator, theme, selectors, and types.
///
/// **Contracts:** MCP server tool names vs in-app runtime bridge names are
/// documented in the repo at `flutter_live_edit/CONTRACT.md` (see
/// `flutter_live_edit_core`).
library;

export 'src/di_live_edit_context/live_edit_scope.dart' show LiveEditScope;
export 'src/host/core/live_edit_host.dart' show FlutterLiveEditHost;
export 'src/host/flutter_auto_host/flutter_live_edit_auto_host.dart'
    show bootstrapFlutterLiveEditApp;
export 'src/live_edit_runtime.dart' show LiveEditRuntime;
export 'src/mcp_toolkit_tools/live_edit_toolkit.dart'
    show getFlutterLiveEditEntries;
