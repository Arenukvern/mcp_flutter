# P4 (consolidation) + adjacent parity gaps — research

**Date:** 2026-04-28. Branch: `live-edit-v2-plannig`. Index: GitNexus run today (7,707 nodes / 17,980 edges).

This document is **research, not a spec.** It evaluates whether the audit's deferred consolidation candidates are worth doing now, and surveys the two remaining parity rows (`file_upload`, `select_option`) for completeness.

## TL;DR

- **P4 consolidation should stay deferred.** The audit's stated bar — "evidence the LLM mis-selects the current shape" — is not met. The current tool descriptions in [interaction_handler.dart](mcp_server_dart/lib/src/mcp_toolkit_server/handlers/interaction_handler.dart) are mechanically distinct (different `required` keys per tool) and the parameter overlaps are minimal. There is no documented selection failure in the repo to point at.
- **Blast radius is small if/when we do consolidate.** Each gesture method has exactly one MCPCallEntry caller (confirmed via GitNexus `context()` — see citations below). The 7-place wire registration pattern means consolidation is mechanical, not cross-cutting. This is a "do it when evidence accrues" item, not "do it before it's hard later."
- **`file_upload` is the only architecturally interesting open gap.** It needs design work (no `file_picker` integration anywhere in the repo today), but is not on the user's stated priority list.
- **`select_option` is correctly deferred** — expressible as `tap_widget → wait_for(text=label) → tap_widget` post-P0; a wrapper saves zero round-trips.

---

## 1. P4 evidence assessment

### 1a. Candidate set A — "tap modes" (`tap_widget` + `long_press` + `hover`)

**Current tool descriptions** (verbatim from [interaction_handler.dart:39–366](mcp_server_dart/lib/src/mcp_toolkit_server/handlers/interaction_handler.dart:39)):

| Tool | required | description |
| --- | --- | --- |
| `tap_widget` | `[ref]` | "Tap a widget identified by ref from semantic_snapshot. Call semantic_snapshot immediately before…" |
| `long_press` | `[ref]` | "Long press a widget identified by ref from semantic_snapshot. Call semantic_snapshot immediately before…" |
| `hover` | `[ref]` | "Synthesize a mouse hover at the centre of a widget by semantic ref. Drives MouseRegion.onEnter/onExit. Desktop/web only — mobile has no hover concept." |

**Parameter shape:** all three take `(ref, snapshotId?)`. **Identical**. The only differentiator the LLM has is the *verb* (tap vs long press vs hover).

**Confusion surfaces:**
- The verb difference *is* the differentiator — if the agent's prompt says "long press X", it picks `long_press`; if "tap X", `tap_widget`. The names map directly to user intent.
- `hover` carries an explicit platform caveat ("Desktop/web only — mobile has no hover concept"). A consolidated `tap(ref, mode='hover')` would have to repeat that caveat in the `mode` parameter description, where it's less prominent.

**GitNexus blast radius** (consolidation cost):
- `tapAtRef` has 1 incoming call: `OnTapWidgetEntry` (toolkit-side).
- `longPressAtRef` has 1 incoming call: `OnLongPressEntry`.
- Each kind has exactly 1 MCPCallEntry → 1 service method. Wire shape uniform across all gestures.
- 7-place pattern means consolidation touches: 3 commands → 1, 3 specs → 1, 3 ext-name constants → 1, 3 Tool defs → 1 (with `mode` enum), 3 dispatch cases → 1, 3 entries → 1, 3 registrations → 1. ~150 LoC delta, mechanical.

**Verdict:** No evidence of mis-selection. The verb-named API is more discoverable than a `mode` enum. Defer until usage data shows otherwise.

### 1b. Candidate set B — "directional gestures" (`scroll` + `swipe`)

**Current tool descriptions** (verbatim from [interaction_handler.dart:85–158](mcp_server_dart/lib/src/mcp_toolkit_server/handlers/interaction_handler.dart:85)):

| Tool | required | description |
| --- | --- | --- |
| `scroll` | `[direction]` | "Scroll in a direction from a ref or from center of screen." |
| `swipe`  | `[direction]` | "Swipe in a direction from a ref or center of screen." |

**Parameter shape:** identical. `(direction, ref?, distance?, snapshotId?)`. The descriptions differ by **one word** ("Scroll" vs "Swipe"). This is the strongest theoretical confusion candidate of the three sets.

But the *behavioural* difference is real:
- `scroll` prefers the semantic `scrollUp/Down/Left/Right` action via `SemanticsOwner.performAction` (Tier 1 in the gesture service). Falls back to a synthetic scroll-wheel signal.
- `swipe` is a **finger drag** synthesized via `PointerDownEvent → moves → PointerUpEvent` over time. It dismisses Dismissible, opens drawers, moves PageView pages — things `scroll` can't do.

These are different physical actions that *happen* to share a directional vocabulary. A consolidated `gesture(ref, kind, direction, distance)` would *encourage* the agent to think of them as variants when they aren't — that's a regression in API truthfulness.

**Verdict:** Do **not** consolidate this pair. The shared parameter shape is misleading; the underlying behaviours diverge meaningfully.

### 1c. Candidate set C — observability split

The audit lists `get_recent_logs` + future `get_network_requests` + future `get_errors` → `observe(kind=...)`.

**Current state:** only `get_recent_logs` exists. `get_network_requests` is the deferred P3 spec ([todo/p3_network_introspection_deferred.md](todo/p3_network_introspection_deferred.md)). No `get_errors` tool exists yet (errors flow through `app_errors` resource, not a tool).

**Why consolidation is premature:** designing the dispatcher API before two of its three inputs exist is YAGNI. When P3 (network) and a future errors-as-tool path both ship, *then* assess whether `observe(kind=...)` reduces selection noise vs three separate verb-named tools.

**Verdict:** Revisit only after P3 ships and errors-as-tool is on the roadmap.

### 1d. Selection-pattern data — the missing input

The audit said: "After `wait_for` lands and is in use, observe selection patterns." `wait_for` shipped 2026-04-27 (commit `0df147e`). At time of writing, no usage data has been collected.

Concrete data sources that would unblock P4:
1. **Real session transcripts** — search MCP server stdio logs for tool-call sequences. Any session that calls `long_press` immediately after `tap_widget` failing on the same ref signals selection confusion.
2. **Agent-prompt audits** — if downstream agent prompts explicitly enumerate "use `tap_widget` for X, `long_press` for Y" disambiguation hints, that's evidence the descriptions are insufficient.
3. **Issue/feedback channel** — if anyone reports "the LLM keeps using `swipe` when it should have used `scroll`", consolidate B.

None of these data sources have been mined as part of this research. Doing so requires session transcripts that don't exist in this repo.

---

## 2. Other parity gaps surveyed

### 2a. `file_upload` — **❌ missing**

[Audit row](todo/playwright_parity_audit.md:85): *"Real apps using `file_picker` are unreachable."*

GitNexus `query` for `file_picker` returns no real results — `file_picker` is not a dependency of any package in the repo (toolkit, server, test app, or live-edit). A `file_upload` tool would need design work covering:

- **Wire shape**: how does the agent represent the file? Inline base64 (small files) vs server-side path the toolkit reads (large files)?
- **Bridge**: `file_picker` returns `XFile`/`File` objects from a native picker dialog. Synthesizing the picker result without showing a dialog needs hooking the package's platform channel mock or registering a test override.
- **Permission**: `file_picker` requires platform permission on iOS/Android.
- **Scope**: limit to debug-mode local file paths to sidestep upload-target ambiguity.

**Recommendation:** Park as a deferred design candidate similar to P3. Do *not* take it on without a host-app driver who needs it — the design surface is wide and unused capability bloats the always-on tool surface.

### 2b. `select_option` — ➖ deferred (correctly)

[Audit row](todo/playwright_parity_audit.md:84) and [P2 plan](docs/superpowers/plans/2026-04-27-p2-fill-form-hover.md): the gap is real but a wrapper saves zero round-trips post-P0.

```
tap_widget(refOfDropdown)
  → wait_for(text=optionLabel)
  → tap_widget(refOfOption)
```

This is already what an agent would do *inside* a `select_option` wrapper. A wrapper would only save bytes. Defer is correct.

---

## 3. Recommended decision

| Item | Action | When to revisit |
| --- | --- | --- |
| P4 set A (`tap`/`long_press`/`hover`) | **Defer** | After 1–2 weeks of real session transcripts; only consolidate if mis-selection observed |
| P4 set B (`scroll`/`swipe`) | **Do not consolidate** | Behavioural divergence makes the shared shape harmful; remove from candidate list in audit |
| P4 set C (observability) | **Defer** | After P3 lands and a third observability tool is on the roadmap |
| `file_upload` | **Park as design candidate** | When a host app needs it; design surface is wide |
| `select_option` | **Stay deferred** | No action |

### Suggested audit edit

The audit currently lists set B in its "Consolidation candidates (deliberately deferred)" section. Based on the behavioural-divergence finding, that entry should be **removed from the candidate list** — not just deferred — and replaced with a line explaining why scroll and swipe should remain separate.

---

## 4. Citations (GitNexus + source)

- Tool descriptions: [interaction_handler.dart:39–366](mcp_server_dart/lib/src/mcp_toolkit_server/handlers/interaction_handler.dart:39).
- Service methods: [gesture_interaction_service.dart:42–542](mcp_toolkit/mcp_toolkit/lib/src/services/gesture_interaction_service.dart:42) (tapAtRef, longPressAtRef, scroll, swipe, drag, hoverAtRef, enterTextAtRef).
- Toolkit-side entries (1:1 with service methods): `OnTapWidgetEntry`, `OnLongPressEntry` etc. in [interaction_toolkit.dart](mcp_toolkit/mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart).
- Audit deferral rationale: [playwright_parity_audit.md:111–128](todo/playwright_parity_audit.md:111).
- GitNexus context queries on `tapAtRef` and `longPressAtRef` confirmed each service method has exactly **1 incoming caller** (the corresponding MCPCallEntry). No cross-cutting consumers.
- Index built today via `gitnexus analyze` after the binary was already installed at `/opt/homebrew/bin/gitnexus`; `npm pkg`-relative `npx gitnexus analyze` failed because the repo has no `package.json`.
