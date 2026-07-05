---
name: flutter-mcp-toolkit-guide
description: Entry point for inspecting or driving a running Flutter app from your AI assistant — routes to the right task skill (inspect / control / debug / custom app surfaces) and runs preflight.
---

<!-- @FMT_MODE_PRELUDE -->

## When to use

Use this skill when the user wants to inspect or drive a running Flutter app
from this conversation. Examples:
- "Tap the login button in my app"
- "Why is the home screen blank?"
- "Take a screenshot and tell me what's broken"
- "Expose my cart / flags / internal state to the agent via MCP"

If the user is asking about Flutter concepts unrelated to a running app
(architecture questions, package selection), this skill does not apply.

## Step 1: Preflight

Always run `flutter-mcp-toolkit doctor --json` first. Parse the output:

- `status: "ok"` — proceed to Step 2.
- `status: "error"` and `error.code: "binary_not_found"` — load
  `flutter-mcp-toolkit-setup` and follow its install instructions.
- `status: "error"` and `error.code: "vm_not_connected"` — load
  `flutter-mcp-toolkit-setup` and follow its troubleshooting section.
- Any other error — load `flutter-mcp-toolkit-debug` and read the error
  envelope playbook.

## Step 2: Pick the right skill for the user's intent

| User intent | Load skill |
|---|---|
| Read state ("what's on screen?", "show me errors", "screenshot") | `flutter-mcp-toolkit-inspect` |
| Drive UI ("tap X", "type into Y", "scroll to Z", "hot reload") | `flutter-mcp-toolkit-control` |
| Diagnose ("why is X failing?", "show recent logs", "evaluate expression") | `flutter-mcp-toolkit-debug` |
| Register app-specific MCP tools/resources (`AgentCallEntry`, `bootstrapFlutter` `additionalEntries`) | `flutter-mcp-toolkit-custom-tools` |
| Upgrade from removed legacy call-entry APIs | `flutter-mcp-toolkit-intentcall-migration` |
| Audit CLI/MCP/schema/dynamic-registry parity before changing tool surfaces | `flutter-mcp-boundary-audit` |
| Maintain `flutter_test_app` web / WebMCP showcase hooks | `flutter-mcp-toolkit-maintain-web` |
| Maintain `flutter_test_app` macOS / native IntentCall hooks | `flutter-mcp-toolkit-maintain-macos` |
| Score dogfood iterations or route dogfood evidence | `flutter-mcp-toolkit-dogfood-iterations` |
| Release, version, or plugin skill bundle maintenance | `flutter-mcp-toolkit-repo-maintainer` |

Harness Script lint/run/Maestro and promo/video capture live in their owner
repositories. Do not look for `flutter-mcp-semantic-test`,
`flutter-mcp-capture`, or `hyperframes-video` in this plugin.

If the task spans more than one (e.g. "tap the button and show me what
changed"), load `inspect` AND `control`. Skills are additive.

## Step 3: Execute

Each task skill has the tool list, parameter shapes, and example calls. Follow
the prelude at the top of the skill — it tells you whether you're calling MCP
tools or shelling out to the CLI.

## Tool taxonomy reference

The core toolkit tools fall into these categories. The full list with
parameter shapes lives in the task skills.

- **Inspection (read-only):** `discover_debug_apps`, `get_app_errors`,
  `get_screenshots`, `get_view_details`, `get_vm`, `get_extension_rpcs`,
  `semantic_snapshot`, `inspect_widget_at_point`, `capture_ui_snapshot`,
  `connect_debug_app`. → `flutter-mcp-toolkit-inspect`.
- **Interaction (mutating):** `tap_widget`, `long_press`, `enter_text`,
  `reveal_search`, `fill_form`, `scroll`, `swipe`, `drag`, `hover`,
  `press_key`, `wait_for`, `navigate`, `handle_dialog`,
  `hot_reload_flutter`, `hot_restart_flutter`, `hot_reload_and_capture`. →
  `flutter-mcp-toolkit-control`.
- **Debug:** `get_recent_logs`, `evaluate_dart_expression`. →
  `flutter-mcp-toolkit-debug`.
- **Dynamic registry (app-defined):** after registration in the Flutter app,
  MCP calls use `fmt_list_client_tools_and_resources`, then
  `fmt_client_tool` / `fmt_client_resource`. When shelling out to the CLI,
  command names appear only as `exec --name <name>` values; do not call bare
  `list_client_tools_and_resources`, `client_tool`, or `client_resource` as
  MCP tools. → `flutter-mcp-toolkit-custom-tools`.
- **Boundary/proof maintenance:** use `flutter-mcp-boundary-audit` before
  changing catalog/schema/registry surfaces; use `flutter-mcp-toolkit-maintain-web`
  or `flutter-mcp-toolkit-maintain-macos` for showcase platform hooks; use
  `flutter-mcp-toolkit-repo-maintainer` for release, version, and generated
  skill-bundle work.

## When in doubt

If `doctor` is green but a tool call fails, read the returned `error.code`
and `error.recovery` fields. The full code → recovery table is in
`flutter-mcp-toolkit-debug`.
