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
| Upgrade after intentcall Phase 6 breaking bump (migrate CLI) | `flutter-mcp-toolkit-intentcall-migration` |
| Harness Script lint/run/Maestro (`*.hs.yaml`, app registry) | Install **flutter_harness** — skill `flutter-mcp-semantic-test` in that repo |
| HS capture bundles / promo video | **flutter_harness** + **flutter_mcp_video** (not bundled in toolkit `init`) |

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
  `fill_form`, `scroll`, `swipe`, `drag`, `hover`, `press_key`, `wait_for`,
  `navigate`, `handle_dialog`, `hot_reload_flutter`, `hot_restart_flutter`,
  `hot_reload_and_capture`. → `flutter-mcp-toolkit-control`.
- **Debug:** `get_recent_logs`, `evaluate_dart_expression`. →
  `flutter-mcp-toolkit-debug`.
- **Dynamic registry (app-defined):** after registration in the Flutter app,
  list with `list_client_tools_and_resources`, then `client_tool` /
  `client_resource` — wire names as **`fmt_*`** when calling MCP. →
  `flutter-mcp-toolkit-custom-tools`.

## When in doubt

If `doctor` is green but a tool call fails, read the returned `error.code`
and `error.recovery` fields. The full code → recovery table is in
`flutter-mcp-toolkit-debug`.
