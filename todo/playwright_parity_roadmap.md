# Playwright Parity — Roadmap

> Companion to `playwright_parity_audit.md`. Sequences the work into
> independently-shippable sub-plans, each producing working software.
>
> Status: roadmap. Per-sub-plan detailed plans live under
> `docs/superpowers/plans/` once accepted.

## Open questions (decide before P0 starts)

### 1. Branching

Current branch `live-edit-v2-plannig` has the live-edit-v2 selection state
machine work in progress (see `todo/selection_state_machine.md`). Stacking
Playwright-parity tools on top will tangle two unrelated efforts:

- **Recommendation:** branch this work off `main` (or off the last green
  commit before live-edit-v2 work began). Land sub-plans incrementally;
  rebase live-edit-v2 on top later.
- Alternative: continue on `live-edit-v2-plannig` if live-edit-v2 is close to
  merge and the user accepts the entanglement.

**Needs user decision.**

### 2. Additions before consolidation (recommended)

Two reasons to ship new tools first and defer the
`tap_widget`/`long_press`/`scroll`/`swipe` merges:

1. **Risk asymmetry.** Additive tools cannot break existing consumers.
   Consolidation can.
2. **Evidence.** We don't yet know which current shapes the LLM mis-selects.
   After `wait_for` and friends are in use, observed selection patterns will
   show whether consolidation actually moves the needle.

So the roadmap orders **adds first**, **consolidation last and conditional**.

### 3. Live-edit & debug-dump tool counts — leave alone?

Audit recommends not touching the 23 live-edit tools or 4 debug-dump tools as
part of parity work. Confirm — if the user wants live-edit tooling auditing,
that's a separate project.

## Priority tiers

| Priority | Sub-plan                                | Size           | Why this tier                                                       |
| -------- | --------------------------------------- | -------------- | ------------------------------------------------------------------- |
| **P0** ✅ | `wait_for` *(shipped 2026-04-27)*       | Design-heavy   | Single tool that changes the feel of every other tool. Solo plan.   |
| **P1** ✅ | Keyboard + dialog + navigate *(shipped 2026-04-27)* | Small batch    | Mechanical once snapshot/gesture infra exists. Bundle as one plan.  |
| **P2**   | Form ergonomics + hover                 | Small batch    | Token wins (`fill_form`, `select_option`) + desktop/web (`hover`).  |
| **P3**   | Network introspection                   | Architecturally heavy | Toolkit-side `HttpOverrides` + ring buffer + opt-in flag.    |
| **P4**   | Consolidation pass (conditional)        | Refactor       | Only if usage data shows mis-selection.                             |

Each sub-plan must produce working, testable software on its own — no
cross-tier dependencies beyond what already exists.

---

## P0 — `wait_for`

**Goal.** Block until a predicate over current UI state is true (or timeout).

**Why first.** Without async-aware waiting, every interaction is racy. Flutter
is *more* async than the web (futures, animations, rebuilds). Sleep+snapshot
loops are wasteful on tokens and unreliable.

### Design questions to surface in the plan (do not bury)

These are **decisions, not implementation**. The plan must enumerate and
answer each:

1. **Predicate language.** Options to evaluate:
   - `text`: substring appears in semantic snapshot.
   - `noText`: substring is absent.
   - `ref`: a ref id from the most recent snapshot is present (or absent).
   - `stable`: snapshot stable (no semantic changes) for N ms.
   - `time`: simple sleep (Playwright has this; ergonomically useful).
   - Combinator? (`all_of`, `any_of`) or single-predicate-per-call?
   - Recommendation: start with `text`, `noText`, `time`, `stable`. Skip
     combinators until evidence demands them.
2. **Polling cadence.** Options:
   - Periodic timer (e.g. 100ms).
   - `WidgetsBinding.instance.addPostFrameCallback` — wake exactly when the
     frame the LLM might care about lands. Lower latency, fewer wakeups.
   - Recommendation: post-frame callback for snapshot-derived predicates;
     timer for `time`.
3. **Timeout.** Default + max (e.g. default 5s, max 30s). Reject larger.
4. **Snapshot interaction.** Does `wait_for` auto-refresh `semantic_snapshot`
   refs in the response? Or return only the predicate result and force a
   follow-up `semantic_snapshot` call?
   - Recommendation: return a fresh `snapshot_id` + condensed snapshot in
     the success payload. Saves a round-trip — the LLM almost always wants
     to act next.
5. **Return shape.** On success: `{matched: true, snapshot_id, snapshot}`.
   On timeout: structured error (`wait_timeout`) with elapsed time, last
   evaluated predicate state, current `snapshot_id`.

### Files (preview — full plan will detail)

- Toolkit: new `services/wait_predicate_service.dart` (post-frame loop).
- Server: new `Tool` + handler in `interaction_handler.dart`.
- Shared: new error code `wait_timeout` in `error_codes.dart`.
- Spec: entry in `commands_specs.dart` + dispatch in `command_executor.dart`.
- Tests: behavioral test for each predicate kind, timeout path, race against
  fast-resolving predicate.

---

## P1 — Keyboard + dialog + navigate (one plan)

Three small tools that share infrastructure (no new toolkit services
required beyond a Navigator handle).

- **`press_key(key, modifiers?)`** — synthesize keyboard event. Use
  `ServicesBinding.instance.keyEventManager.handleKeyMessage` or equivalent;
  matches the gesture two-tier pattern.
- **`handle_dialog(action: accept|dismiss, text?)`** — find topmost dialog,
  invoke its action without snapshot round-trip.
- **`navigate(action: push|pop|popUntil, route?, args?)`** — toolkit holds a
  `GlobalKey<NavigatorState>` (apps already commonly expose this) and calls
  `Navigator.pushNamed` / `pop`. App opt-in: register the navigator key with
  `MCPToolkit`.

Decision: bundle as one plan — same toolkit-side wiring file
(`services/control_flow_service.dart`), same handler section.

---

## P2 — Form ergonomics + hover

- **`fill_form(fields: [{ref, text}])`** — batch text entry. Pure server-side
  loop over `enter_text`; no new toolkit service.
- **`select_option(ref, value | index)`** — Flutter-aware DropdownButton/
  DropdownMenu helper. Opens menu, taps target item.
- **`hover(ref)`** — pointer enter/exit pair via existing pointer-event tier.

Same plan; small.

---

## P3 — Network introspection

**Architecturally heavy.** Separate plan.

- Toolkit: install a custom `HttpOverrides` (or `HttpClient`-wrapping
  `dio`/`http` interceptor for those packages — but `HttpOverrides` is the
  universal hook for `dart:io` HTTP).
- Ring buffer of N most recent requests with bounded body size.
- Opt-in flag (off by default — privacy + perf).
- Tools:
  - `get_network_requests(count?, filter?)` — recent calls, status, timing,
    truncated body.
  - `clear_network_requests()` — reset buffer.

Privacy contract: document body capture limit, redact common header names
(`Authorization`, `Cookie`).

---

## P4 — Consolidation (conditional)

Only proceed if evidence (usage logs, observed mis-selection) shows the
current shape hurts the LLM. Candidates from the audit:

- `tap_widget` + `long_press` + `hover` → `tap(ref, mode=tap|long|hover)`
- `scroll` + `swipe` → `gesture(ref, kind, direction, distance)`
- `get_recent_logs` + `get_network_requests` + (errors) →
  `observe(kind=logs|errors|network)`

Breaking changes: keep old tool names as deprecated shims for one release
cycle.

---

## Done definition for "Playwright parity"

The interaction LLM workflow `snapshot → act → wait → verify` works
end-to-end on Flutter without sleep+snapshot guessing, with HTTP traffic
visibility, keyboard input, dialogs, and navigation. P0–P3 shipped. P4
considered.

## Pause point

Before writing the P0 plan in detail, confirm with the user:

1. Branching decision (Q1 above).
2. Sub-plan ordering / scope (P0–P4 as listed?).
3. Live-edit & debug-dump tools genuinely out of scope (Q3 above)?

Then write `docs/superpowers/plans/<date>-wait-for.md` per writing-plans
skill.
