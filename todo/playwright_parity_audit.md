# Playwright Parity — Tool Audit

> Trimmed 2026-04-29 post-v3.0.0. The shipped P0–P2 status,
> per-tool implementation notes, and source-file references are now
> reflected in `CHANGELOG.md` and the locked surface at
> `tool/contracts/expected_tool_surface.txt`. This file keeps only
> the framing decisions that informed the v3.0.0 scope and that
> still inform P3/P4 prioritisation.

## Headline reframe

The "~47 tools" framing that gets used in conversation is misleading:
it conflates surfaces the LLM rarely sees together. The Playwright
parity comparison only makes sense against the **always-on core**.

| Surface                            | When loaded                      |
| ---------------------------------- | -------------------------------- |
| Always-on core                     | every session                    |
| Live-edit (separate vertical)      | not shipped in v3.0.0            |
| Debug dumps                        | `--dumps` opt-in (token-heavy)   |
| Resources-as-tools fallback        | `--no-resources` mode            |
| Dynamic registry (app-registered)  | per-app, registered at runtime   |

The actual delta vs. Playwright (~21 tools) is **count-comparable, not a
3× problem**. The interesting question is *coverage* and *clarity of
contract*, not headline count.

## What we have that Playwright doesn't (the moat — keep sharp)

These are **not** dilution candidates in any future consolidation pass:

- `core_hot_reload_and_capture` — fused edit/preview cycle.
- `core_evaluate_dart_expression` — runtime introspection via VM service.
- `core_semantic_snapshot` staleness sentinel (`snapshot_id` +
  `stale_snapshot` error code) — explicit contract Playwright lacks.
- Dynamic tool registration (app-side registry) — apps inject their own
  tools at runtime, surfaced via `listClientToolsAndResources`.
- Resource path: `visual://localhost/...` URIs alongside tools.

## Still missing vs. Playwright after v3.0.0

| Capability               | Status                            | Where tracked |
| ------------------------ | --------------------------------- | ------------- |
| `network_requests`       | ❌ no HTTP introspection           | `todo/p3_network_introspection_deferred.md` |
| `select_option`          | ➖ expressible as `tap → wait_for(text) → tap`; thin wrapper saves zero round-trips | n/a — keep deferred |
| `file_upload`            | ❌ apps using `file_picker` unreachable; needs host driver | n/a — deferred |
| `navigate_back`          | ❌ thin wrapper over Navigator.pop; bundle with any navigate revisit | n/a |
| `resize`                 | ❌ desktop/web responsive testing; low priority | n/a |
| `tabs` / `close`         | ➖ N/A for Flutter session model   | n/a |

## Consolidation candidates (deliberately deferred)

Reasonable-looking merges that would shrink the always-on surface:

- `core_tap_widget` + `core_long_press` + `core_hover` → `core_tap(ref, mode=tap|long|hover)`
- `core_scroll` + `core_swipe` → `core_gesture(ref, kind, direction, distance)`
- Observability split (`core_get_recent_logs`, future
  `core_get_network_requests`, future `core_get_errors`) →
  `core_observe(kind=logs|errors|network)` dispatcher

**Not recommended** until usage data justifies it. Reasoning preserved
in `todo/p4_consolidation_research_2026-04-28.md`. Headline: consolidation
is a breaking change; we don't yet have evidence the current shape causes
mis-selection.
