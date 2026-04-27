# Playwright Parity — Tool Audit

> Goal: ground the "match Playwright" conversation in actual numbers, not the
> "we have 47, they have 21" framing. Determine what we'd add, what we'd
> consolidate, and (deliberately) what we'd leave alone.
>
> Status: audit only. Roadmap and per-feature plans live in sibling docs.

## Headline reframe

The "~47 tools" figure is misleading. It conflates three independent surfaces
that the LLM rarely sees all at once:

| Surface                            | Tools     | When loaded                      |
| ---------------------------------- | --------- | -------------------------------- |
| **Always-on core**                 | **18**    | every session                    |
| Live-edit (separate vertical)      | 23        | `--live-edit` enabled            |
| Debug dumps                        | 4         | `--dumps` opt-in (token-heavy)   |
| Resources-as-tools fallback        | 3         | `--no-resources` mode            |
| Dynamic registry (app-registered)  | variable  | per-app, registered at runtime   |

**The Playwright comparison should target the always-on core (18 tools), not
the conditional surfaces.** Live-edit is its own product workflow (session →
draft → resolve → apply) and shouldn't be folded into the parity discussion.
Debug dumps are an opt-in expert tool. Dynamic registry is a feature, not a
fixed surface.

Playwright MCP exposes ~21 tools, all in its always-on surface. So the real
delta is **18 vs 21** — and the question is *coverage*, not count.

## Always-on core inventory (18)

Source: `mcp_server_dart/lib/src/mcp_toolkit_server/mixins/flutter_inspector.dart:55-107`

### VM lifecycle (6) — `vm_tools_handler.dart`
- `connect_debug_app`
- `hot_reload_flutter`
- `hot_restart_flutter`
- `get_vm`
- `get_extension_rpcs`
- `discover_debug_apps`

### Inspection (2) — `resource_handler.dart`
- `inspect_widget_at_point`
- `capture_ui_snapshot`

### Interaction (10) — `interaction_handler.dart`
- `semantic_snapshot` *(spine — issues `s_0`, `s_1`, ... refs)*
- `tap_widget`
- `enter_text`
- `scroll`
- `long_press`
- `swipe`
- `drag`
- `hot_reload_and_capture`
- `evaluate_dart_expression`
- `get_recent_logs`

## Playwright MCP — reference surface (~21)

Captured from current Playwright MCP plugin at the time of audit (subject to
upstream changes; revisit if their tool list shifts).

| Group         | Tools                                                                                                                |
| ------------- | -------------------------------------------------------------------------------------------------------------------- |
| Interaction   | `browser_click`, `browser_drag`, `browser_hover`, `browser_type`, `browser_press_key`, `browser_fill_form`, `browser_select_option`, `browser_file_upload` |
| Observation   | `browser_snapshot`, `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests`                |
| Lifecycle     | `browser_navigate`, `browser_navigate_back`, `browser_tabs`, `browser_close`, `browser_resize`                       |
| Execution     | `browser_evaluate`, `browser_run_code`                                                                               |
| Control flow  | `browser_handle_dialog`, `browser_wait_for`                                                                          |

## Gap matrix — Playwright capability → MCP Flutter status

Legend: ✅ covered · ⚠️ partial · ❌ missing · ➖ N/A for Flutter context.

| Playwright capability             | MCP Flutter status                              | Notes                                                                                                                                                                                                       |
| --------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`wait_for`** (text/element/time) | **❌ missing**                                  | Biggest gap. Without it every interaction is racy: LLM has to guess sleep + snapshot loops. Flutter UIs are async-heavy (futures, animations, rebuilds), so this hurts more than on the web.                |
| `network_requests`                | **❌ missing**                                  | No HTTP traffic introspection. Cannot verify "did login POST happen". Needs toolkit-side `HttpOverrides` hook + ring buffer. **Architecturally heavy** — its own sub-plan.                                   |
| `press_key`                       | **❌ missing**                                  | `enter_text` only covers text fields. No way to send Esc / Tab / Enter / arrows for focus traversal or keyboard shortcuts.                                                                                  |
| `handle_dialog`                   | **❌ missing**                                  | Today: must `semantic_snapshot` then `tap_widget` on the OK ref. A first-class accept/dismiss avoids the snapshot round-trip.                                                                               |
| `navigate` (push/pop named route) | **❌ missing**                                  | Today: hot-reload to change routes. Wasteful. Needs Navigator handle on toolkit side.                                                                                                                       |
| `fill_form`                       | **❌ missing**                                  | N `enter_text` calls vs one batch. Pure token win.                                                                                                                                                          |
| `select_option`                   | ➖ deferred                                      | Expressible as `tap_widget → wait_for(text=label) → tap_widget` post-P0; thin wrapper would save zero round-trips. Revisit if usage data shows the wrapper is worth the surface area. (Originally in P2 scope; dropped during P2 brainstorming, same logic that killed `handle_dialog accept` in P1.) |
| `file_upload`                     | **❌ missing**                                  | Real apps using `file_picker` are unreachable.                                                                                                                                                              |
| `hover`                           | **❌ missing**                                  | Desktop/web Flutter only — tooltips and hover states unreachable.                                                                                                                                           |
| `click` / tap                     | ✅ `tap_widget`                                  | —                                                                                                                                                                                                           |
| `drag`                            | ✅ `drag`                                        | —                                                                                                                                                                                                           |
| `type`                            | ✅ `enter_text`                                  | Uses `userUpdateTextEditingValue` — formatters + onChanged fire correctly.                                                                                                                                  |
| `snapshot`                        | ✅ `semantic_snapshot`                           | Has staleness sentinel (`snapshot_id`) — *better* than Playwright's contract here.                                                                                                                          |
| `take_screenshot`                 | ✅ `capture_ui_snapshot` / `get_screenshots`     | —                                                                                                                                                                                                           |
| `console_messages`                | ⚠️ `get_recent_logs`                            | Captures `debugPrint`. Doesn't surface `FlutterError.onError` framework errors uniformly. Partial.                                                                                                          |
| `evaluate` / `run_code`           | ✅ `evaluate_dart_expression`                    | Single tool covers both Playwright variants.                                                                                                                                                                |
| `navigate_back`                   | ❌ missing                                       | Bundle with `navigate` plan.                                                                                                                                                                                |
| `tabs`                            | ➖ N/A                                           | Flutter mobile/desktop generally single-window. Skip.                                                                                                                                                       |
| `resize`                          | ❌ missing                                       | Useful for desktop/web Flutter responsive testing. Low priority.                                                                                                                                            |
| `close`                           | ➖ partial                                       | `hot_restart_flutter` is the analogue. Skip.                                                                                                                                                                |

## What we have that Playwright doesn't (the moat — keep sharp)

These are **not** to be diluted in the consolidation pass:

- `hot_reload_and_capture` — fused edit/preview cycle (Three.js-inspired).
- `evaluate_dart_expression` — runtime introspection via VM service.
- `semantic_snapshot` staleness sentinel (`snapshot_id` + `stale_snapshot`
  error code) — explicit contract that Playwright's snapshot lacks.
- Dynamic tool registration (app-side registry) — apps inject their own tools.
- Live-edit overlay vertical — separate workflow surface, not a Playwright
  competitor.

## Consolidation candidates (deliberately deferred)

Reasonable-looking merges that would shrink the always-on surface:

- `tap_widget` + `long_press` + (future) `hover` → `tap(ref, mode=tap|long|hover)`
- `scroll` + `swipe` → `gesture(ref, kind, direction, distance)`
- Observability split (`get_recent_logs`, future `get_network_requests`,
  future `get_errors`) → `observe(kind=logs|errors|network)` dispatcher

**These are not in this audit's recommendations.** Reasoning:

1. Consolidation is a **breaking change** to a published-ish surface. Risk
   profile differs from additive work.
2. We don't yet have *evidence* the LLM mis-selects the current shape. After
   `wait_for` lands and is in use, observe selection patterns. Maybe
   `tap_widget`/`long_press` separation isn't the bottleneck.

Consolidation is a P4 / conditional sub-plan in the roadmap.

## Out of scope for parity work

- Live-edit tools (23) — separate vertical workflow.
- Debug dumps (4) — opt-in expert tools, fine as-is.
- Resources-as-tools fallback (3) — controlled by `--no-resources` switch.
- Dynamic registry — feature, not surface.

## Sources

- `mcp_server_dart/lib/src/mcp_toolkit_server/mixins/flutter_inspector.dart`
  — registration site for all static tools.
- `mcp_server_dart/lib/src/mcp_toolkit_server/handlers/{vm,interaction,resource,debug,live_edit}_tools_handler.dart`
  — tool definitions.
- Memory: `project_mcp_flutter_interaction_layer.md` — phase 1–5 build notes
  for the interaction layer (gesture two-tier design, staleness sentinel).
