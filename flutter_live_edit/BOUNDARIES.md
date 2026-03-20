# Live Edit — package boundaries

## Toolkit → agent (explicit)

`flutter_live_edit_toolkit` declares a dependency on **`flutter_live_edit_agent`** because **auto/bootstrap** code (`lib/src/live_edit_auto.dart`, `live_edit_auto_delegate.dart`) wires **`LiveEditAgentService`** and related types for in-process orchestration when using the opinionated bootstrap path.

**Policy (5a):** This is intentional for the current architecture. Apps that only need `LiveEditScope` / host widgets without agent bootstrap can still pull the package; the agent types are used only from the auto entrypoints.

A future **5b** refactor could introduce core-level **ports** and inject the agent only from the MCP server process, removing the dependency from the toolkit. That is a larger change and is not required for contract centralization.

## Apps under test

Consumer apps (e.g. `flutter_test_app`) should prefer depending on **`flutter_live_edit_toolkit`** + **core** + **ui_kit** and avoid importing **`flutter_live_edit_agent`** unless they implement custom agent wiring.
