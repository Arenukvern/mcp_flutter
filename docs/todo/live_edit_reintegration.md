# Live-edit re-integration — plan

> **Status:** deferred. The capability kernel shipped in v3.0.0 ([ADR 0001](../decisions/0001_capability_kernel_and_tool_prefix.mdx))
> as the carrier; live-edit itself was excised pending this re-integration.
> Resume by feeding this file into `superpowers:writing-plans`.
>
> Consolidates: `tool_surface_inversion.md` (live-edit re-integration plan)
> + `selection_state_machine.md` (the v3.0-era state machine refactor).

## Goal

Reintroduce live-edit as a separate **capability** (a `mcp_capability_live_edit`
package) layered on the kernel. The shipped capability surface is `live_edit_*`;
the server stays Flutter-free; the toolkit re-acquires its
`flutter_live_edit_toolkit` companion. As part of the re-integration, ship the
selection state-machine refactor — the live-edit selection layer was already
mid-refactor when live-edit was excised, and re-introducing the old shape would
re-introduce the same disambiguation bugs.

## Scope

Three sub-efforts, sequenced:

1. **Capability extraction.** Re-create `live_edit_models` (originally T3 of
   tool-surface inversion), then `mcp_capability_live_edit` and
   `flutter_live_edit_toolkit`. Wire into a custom `main.dart` that registers
   `core` + `live_edit`.
2. **Selection state machine.** Rewrite the pointer-driven layer (hover, tap,
   marquee, candidate cycling) as an explicit state machine. This is the
   largest piece by LoC and the riskiest one to defer further.
3. **Sketch overlay.** Free-form annotation that attaches to the active bubble
   as multimodal agent context.

Each sub-effort is independently shippable behind a feature flag; sub-effort 2
gates 3.

---

## Sub-effort 1 — Capability extraction

### Command split (verified pre-excision; classification may shift ±1 once bodies are re-read)

| Command                           | Side    | Why                                   |
|-----------------------------------|---------|---------------------------------------|
| `LiveEditStartSession`            | server  | hot-reload coordination, agent setup  |
| `LiveEditPrepareSession`          | server  | hot reload + VM service prep          |
| `LiveEditSetOverlay`              | app     | pure app-state mutation               |
| `LiveEditGetTree`                 | app     | pure app-state read                   |
| `LiveEditSelectAtPoint`           | app     | pure app-state mutation               |
| `LiveEditGetSelection`            | app     | pure app-state read                   |
| `LiveEditGetCapabilities`         | app     | pure app-state read                   |
| `LiveEditGetSelectionCandidates`  | app     | pure app-state read                   |
| `LiveEditSetActiveSelection`      | app     | pure app-state mutation               |
| `LiveEditGetPropertyPanel`        | app     | pure app-state read                   |

Server-side commands need the server because of hot-reload coordination through
the VM service and agent orchestration (Codex / Cursor SDK calls). Everything
else lives where the data lives — in the running Flutter app.

### Prerequisites
- `live_edit_models` extraction (originally T3): the package has to be reborn
  before `mcp_capability_live_edit` can re-import it.
- `DynamicRegistryBridge` host service interface — designed but not yet
  implemented in the kernel ([ADR 0001](../decisions/0001_capability_kernel_and_tool_prefix.mdx)
  notes it as planned alongside this work). Required for the dynamic-registry
  surface to span both `core` and `live_edit`.

### Tool-name shape
All tools surface as `live_edit_<name>` (e.g. `live_edit_set_overlay`,
`live_edit_get_tree`). The kernel applies the prefix; the capability passes
bare names. No deprecation aliases for the pre-v3 unprefixed names — see
[ADR 0001](../decisions/0001_capability_kernel_and_tool_prefix.mdx)
on hard cuts.

---

## Sub-effort 2 — Selection state machine

### Why this rewrite is required, not optional

Pre-v3, all pointer-driven work — hover, tap-to-select, candidate cycling,
marquee, deeper-pick — lived in one surface spread across ~3,000 LOC in the
live-edit toolkit. The surface had to disambiguate "is this a hover, a click,
or the start of a drag" at every command entry. The mix of `shouldNotify`,
`_sameHoverRequest` distance guards, and a hover cache produced 10 failing
tests at the time of excision (the "deeper hover advances to next cached
candidate" / "repeated marquee updates with same result do not churn
listeners" cluster).

Browsers and design-tool canvases (tldraw, Excalidraw) solve this with an
**explicit state machine**: each pointer phase lives in its own state; hover
only exists in `Idle`; marquee only exists in `Brushing`; no single handler
multiplexes. No-op guards move to the *commit* boundary (equality on the
result), not the input boundary.

### States (sealed)

```
Idle               — default. hover only.
PointingShape      — pointer down on widget. ambiguous: tap vs drag.
PointingCanvas     — pointer down on empty. ambiguous: deselect vs marquee.
Brushing           — rubber-band marquee. entered from PointingCanvas + drag threshold.
Sketching          — free-form annotation. entered from mode switch (toolbar / modifier).
```

### Transitions

```
Idle ──pointerDown on shape──▶ PointingShape
Idle ──pointerDown on empty──▶ PointingCanvas
Idle ──enterSketchMode──────▶ Sketching
PointingShape ──move < threshold, up──▶ Idle  (click = select)
PointingShape ──move ≥ threshold──▶ Idle      (future: Translating; for now drop to idle + start marquee from origin if appropriate)
PointingCanvas ──move < threshold, up──▶ Idle (click empty = clear selection)
PointingCanvas ──move ≥ threshold──▶ Brushing
Brushing ──pointerUp──▶ Idle                  (commit marquee → selection)
Sketching ──exitSketchMode / Escape──▶ Idle   (commit strokes → active bubble)
```

Drag threshold: `16` square-px (mouse), `36` square-px (coarse/touch),
matching tldraw's defaults.

### Migration phases (each shippable behind `useSelectionStateMachine` flag)

| Phase | Deliverable | Notes |
| --- | --- | --- |
| 0 | `HitTestService` extracted as a pure interface; behavioral goldens for hover/marquee/candidate cycling | No state machine yet; just isolates the pure layer. |
| 1 | `SelectionController` + `Idle` / `PointingCanvas` / `Brushing` behind the flag | Parallel run: legacy command path active when flag off; controller writes to separate stores when on. |
| 2 | Hover + marquee migrated; flag-on by default | Delete `_sameHoverRequest`, `shouldNotify`, hover-cache reuse. The 4 cluster-D tests pass. |
| 3 | Tap + candidate cycling migrated | Command surface unchanged; internals go through controller. |
| 4 | `Sketching` state + sketch overlay (sub-effort 3) | See below. |
| 5 | Flag deleted; `live_edit_session_service_core.dart` < 300 LOC | No `_sameHoverRequest` / hover-cache / reuse guards left anywhere. |

Each phase ends green on `flutter test` in the toolkit package.

---

## Sub-effort 3 — Sketch overlay

### Pipeline

```
strokes (multi-touch, in-session) → flatten to PNG image → attach to bubble → normal apply flow consumes image.
```

The stroke list is the *working* representation while drawing (cheap append,
easy `CustomPaint` rendering). On commit, flatten to a PNG once. The agent
payload is the image — strokes are not serialized.

### Decisions

1. **Entry point:** toolbar chip in the selection bubble header. No
   modifier-key shortcut in the initial ship.
2. **Artifact format:** vector strokes in-session only; commit flattens to a
   PNG and attaches `LiveEditSketchAnnotation` (image + bounds + merge mode)
   to the bubble record. The image is what the agent receives.
3. **Merge modes:** both `override` and `append`. Toggled via a three-state
   chip (off / override / append). Override resets the canvas; append loads
   the bubble's prior PNG as background, commit re-flattens over it.
4. **Multi-touch:** each active pointer ID owns its own in-progress stroke;
   commit on chip toggle (not on pointer-up) so in-progress strokes from
   other fingers aren't lost.
5. **Persistence:** `LiveEditBubbleRecord` gains an optional
   `sketchAnnotation` field. Append mode reads the prior image off it.
6. **Payload cap:** PNG ≤ 1024×1024 and ≤ 200 KB; downsample on commit if
   overlay is larger. Prevents runaway payloads on high-DPI screens.
7. **Multimodal-first:** image attachment for Claude/GPT-4o/Codex-multimodal.
   Text-only fallback is a tiny `"User provided a sketch ${w}x${h}px"`
   summary plus `mergeMode` — known-low-quality; revisit only if text-only is
   a real use case.

### Test coverage (additions to phase 4)

- multi-touch: two pointer IDs produce two independent strokes.
- commit: flatten produces a valid PNG of expected size.
- override: re-entering discards prior image.
- append: re-entering loads prior image as background; commit output
  includes both.
- apply payload: request carries `sketchAnnotation` round-trip through JSON.
- size cap: large overlay gets downsampled to ≤ 1024 px on commit.

### Open questions

- **Shared sketches across bubbles.** Bubble-scoped by design. Revisit only
  if users ask for session-wide overlays.
- **Retouch UX for persistent sketches.** Append mode supports accretion;
  no explicit "edit prior strokes" affordance (they're flattened). Could
  re-introduce vector storage later without breaking the wire format.

---

## Risks

| Risk | Mitigation |
| --- | --- |
| Feature flag bifurcation drags on | Deadline: flag off at end of phase 2, deleted in phase 5. No flag-dependent logic outside those files. |
| Golden tests lock in current bugs | Phase 0 goldens are behavioral, not pixel-level. Assert on selection sets / hover IDs / marquee bounds, not layout. |
| Sketch payload bloats request size | Hard cap at 1024×1024 / 200 KB PNG on commit. |
| Append mode desyncs after rollback | Bubble keeps `sketchAnnotation` on rollback; re-entering append mode rebuilds `baseImage` from preserved PNG. |
| `Translating` state needed for drag-reorder later | Out of scope; phase 2 documents that "drag on shape" = no-op today. Slots in between `PointingShape` and `Idle` when needed. |

## Definition of done

- `flutter test` green in `mcp_capability_live_edit`, `flutter_live_edit_toolkit`,
  `mcp_server_dart`, `mcp_toolkit`.
- `live_edit_session_service_core.dart` < 300 LOC.
- No `_sameHoverRequest` / hover-cache / reuse guards left in the codebase.
- `LiveEditSketchAnnotation` serializes round-trip; the live-edit auto-delegate
  includes it in the agent payload.
- User can toggle sketch mode from the bubble, draw, apply, and see the sketch
  referenced in the applied prompt / plan.
- All `live_edit_*` tools registered through the kernel; no static
  `mcp_server_dart → flutter_live_edit_toolkit` dep.
