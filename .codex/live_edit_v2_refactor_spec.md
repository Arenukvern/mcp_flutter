# Live Edit v2 Refactor

## Objective
Refactor the current live-edit stack into a typed, cache-backed interaction platform that removes selection freezes and state churn while establishing the runtime spine for future flow-canvas features.

## Scope
- Replace raw-map-heavy live-edit runtime internals with typed selection, draft, flow, and agent-context models.
- Reset selection correctness around stable keys, canonical selection sets, deduped candidates, and invariant checks.
- Introduce scan/rank/hydrate selection processing with cache-backed inspector data and throttled recomputation.
- Replace nested session/domain state maps with typed per-session stores and snapshot-driven resource propagation.
- Add a runtime-observed flow graph spine with screen and transition snapshots.
- Replace broad agent request `meta`/`evidence` payloads with typed flow-aware envelopes and budgets.
- Update public live-edit tools/resources to use the v2 contract surface.
- Add regression, invariant, and flow-oriented tests for the new behavior.

## Non-goals
- No direct property editing workflow.
- No long-lived dual-runtime adapter layer.
- No full interactive flow canvas in this change; only the graph foundation and read-only view-model boundary.

## Constraints
- Preserve the product model `Target -> Instruct -> Plan -> Apply`.
- Keep current overlay, bubble, and panel UX as the shipped interaction surface.
- Keep raw JSON/maps only at codec, MCP, and wire boundaries.
- Prefer small, reversible slices with bounded write scope.

## Validation Targets
- `dart test` in `flutter_live_edit/flutter_live_edit_toolkit`
- Focused regression tests for selection, session resources, flow graph, and agent context compaction

## Exit Criteria
- Selection identity is stable and canonical across single-select, multi-select, candidate cycling, and marquee flows.
- Reselecting the same element is a no-op and no duplicate public state transitions occur for one gesture.
- Session/resource state is driven by typed snapshots instead of nested runtime map fan-out.
- Flow graph state is captured from runtime navigation and available without tree inspection by downstream views.
- Agent requests use compact typed v2 context with deterministic truncation limits.
