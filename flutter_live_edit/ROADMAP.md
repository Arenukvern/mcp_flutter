# Live Edit Rebuild — Parallel Execution Roadmap

Execute **Phase 0** once (single agent). Then **Tracks A–G** can run in parallel by different agents; each track lists inputs, outputs, and dependencies.

---

## PRD constraints (all tracks)

- **User flows**: Start, Select (appScene only for cycle/hover/select), Bubble (collapse/expand, open, instruction, discuss→plan, submit, approve/apply, auto-close when empty + click elsewhere, one bubble = one lead agent), Plan, Apply, Panel (collapse/expand, drag, resize, all bubble statuses + navigate), Backend (global + per-bubble or one-for-all).
- **No direct property modification** — selection is for AI targets only.
- **Debug mode**: When enabled, show **how the model thinks** (reasoning/thinking trace from the agent) in a dedicated debug pane or inline in the bubble. All model-thinking payloads must be defined with Freezed and serializable.
- **Models**: Define **every** domain model with **Freezed only**. Use `from_json_to_json` for JSON (de)serialization where needed; use `is_dart_empty_or_not` for emptiness checks (strings, collections, optional fields). No hand-written `toJson`/`fromJson` for domain models; use codegen.
- **Architecture**: Command–Resource pattern + app_architecture. UI → Command → Service → Resource → UI. Resources hold state (immutable ResourceData); Commands take only `LiveEditContext` (no Controller). DI for Resources and Services.

---

## Phase 0 — Clean slate (run first, single agent)

**Goal**: Remove all existing implementation so new code can be written fast. Keep package layout and minimal pubspecs.

**Actions**:

1. **flutter_live_edit_core**
   - Delete everything under `lib/src/` except keep one stub: e.g. `lib/flutter_live_edit_core.dart` exporting an empty placeholder or a single `LiveEdit` typedef so the package still resolves.
   - Remove generated files: `*.freezed.dart`, `*.g.dart`.
   - Keep `pubspec.yaml`; add deps: `freezed_annotation`, `json_annotation`, `from_json_to_json`, `is_dart_empty_or_not` (and existing `collection`). Keep `build_runner`, `freezed`, `json_serializable` in dev_dependencies.

2. **flutter_live_edit_toolkit**
   - Delete entire `lib/src/` directory (commands, resources, services, host, overlay, context, controller, selectors, types, scope, orchestrator, glue, theme, backend utils, widgets).
   - Delete entire `test/` directory (or leave one empty test file so tests can be re-added).
   - Keep `lib/flutter_live_edit_toolkit.dart` as a single export file (can be empty or re-export a single placeholder).
   - Keep `pubspec.yaml` with dependencies on `flutter_live_edit_core`, `from_json_to_json`, `is_dart_empty_or_not`, Flutter, etc.; remove any references to deleted files.

3. **flutter_live_edit_agent**
   - Delete everything under `lib/src/` that implements the current agent (plan, request summary, service, validation, utils). Keep package and `pubspec.yaml`; stub export in `lib/`.

4. **live_edit_tooling_ui_kit**
   - Delete implementation under `lib/src/` (panel, bubble, common). Keep package and pubspec; stub export.

5. **live_edit_tooling_ui_kit_playground**
   - Optional: delete app code under `lib/` and leave a minimal `main.dart` that does nothing or shows a placeholder. Keep pubspec.

6. **Integration**
   - In `flutter_test_app`: remove or stub integration tests that depend on live edit; remove live edit usage from `main.dart` if needed so the app still runs (or leave a commented integration point).

**Deliverable**: Repo builds; `flutter pub get` and `dart analyze` pass for `flutter_live_edit_core` and `flutter_live_edit_toolkit`. All previous live edit behavior is removed.

---

## Track A — Core models (Freezed only)

**Depends on**: Phase 0 done.

**Owner**: Agent A.

**Scope**: `flutter_live_edit_core` only. Define every domain model with Freezed. Use `from_json_to_json` for (de)serialization where it simplifies code; use `is_dart_empty_or_not` for any emptiness checks in model methods or constructors.

**Models to define** (non‑exhaustive; add any missing from PRD):

- Session: `LiveEditSessionData`, `LiveEditTargetDomain` (enum).
- Selection: `LiveEditSelection`, `LiveEditSelectionCandidate`, `LiveEditSelectionLayerData`, `LiveEditSourceTarget`, `LiveEditSourceLocation`, `LiveEditBounds`.
- Draft: `LiveEditDraftLayerData`, `LiveEditDraftChange` (no direct property editing; draft is for agent-applied changes only).
- Bubble: `LiveEditBubbleRecord`, `LiveEditBubbleStatus`, `LiveEditBubbleDisplayState`, `LiveEditLayerViewState` (immutable), `LiveEditBubbleSummary`, `LiveEditApplyPhase`, `LiveEditExecutionPlan`, `LiveEditRuntimeEvent`, `LiveEditRuntimeEventKind`, `LiveEditTimelineEntry`, `LiveEditActivityEntry`, `LiveEditActivityStep`.
- Apply: `LiveEditApplyDraftRequest`, `LiveEditApplyMode`, `LiveEditRuntimeAction`, `LiveEditRuntimeRefreshResult`, `LiveEditFilePatch`, `LiveEditResolutionProposal`, `LiveEditResolutionRequest`, etc.
- Backend: `LiveEditAgentBackend`, `LiveEditInferenceConfig`, `LiveEditCodexModelOption` (or equivalent).
- Panel: `LiveEditPanelViewData`, `LiveEditPanelDisplayMode`.
- **Debug**: `LiveEditModelThinking` (or similar) — Freezed model for “how the model thinks” (e.g. steps, reasoning chunks, timestamps). Must be serializable and consumable by the debug UI.

**Rules**:

- Every model is a `@Freezed(fromJson: true, toJson: true)` (or `fromJson: false` only when no JSON is needed) class or an enum with wire names.
- Use `is_dart_empty_or_not` for checks like `string.isNullOrEmpty`, collection empty, etc., in getters or small helpers used by models.
- No hand-written mutable DTOs; no `final class` with manual `copyWith` for domain data.
- Single entrypoint: `lib/src/live_edit_models.dart` (and generated `.freezed.dart` / `.g.dart`). Export from `lib/flutter_live_edit_core.dart`.

**Deliverable**: All models in core, Freezed-only, build_runner passing, tests for (de)serialization and emptiness where relevant.

---

## Track B — Resources and ResourceData

**Depends on**: Track A (core models exist).

**Owner**: Agent B.

**Scope**: `flutter_live_edit_toolkit`: Resources and their Data types. Resources are `ValueNotifier<ResourceData>`. ResourceData is immutable (use Freezed or immutable data classes from core).

**Resources**:

- `LiveEditSessionResource` → `LiveEditSessionResourceData` (or use core `LiveEditSessionData` if it fits).
- `LiveEditSelectionResource` → state: `Map<sessionId, Map<LiveEditTargetDomain, LiveEditSelectionLayerData>>`.
- `LiveEditDraftResource` → state: same shape for draft layer data.
- `LiveEditBubbleResource` → `LiveEditBubbleResourceData` (bubble records, layer view state per domain, apply phase, pending plan, errors, resolved ids, global composer text). All immutable.
- `LiveEditPanelViewResource` → placement, size, expanded/rail, display mode.
- `LiveEditBackendConfigResource` → global backend id, available backends, inference config per backend.

**Rules**:

- No dependencies in Resources (no get_it, no Services). Data only.
- ResourceData lives in `*.src.data.dart` or re-exports from core; use `context.read` / `context.select` in UI.
- File naming: `live_edit_session.src.dart`, `live_edit_session.src.data.dart` (or data in core).

**Deliverable**: All Resources and ResourceData types; barrel `resources/resources.dart`; no business logic inside Resources.

---

## Track C — Services

**Depends on**: Track A (core models).

**Owner**: Agent C.

**Scope**: `flutter_live_edit_toolkit`: Services only. Each service is a focused capability. Use `from_json_to_json` and `is_dart_empty_or_not` where appropriate.

**Services**:

- `LiveEditApplyService` — takes `LiveEditApplyDraftRequest`, calls apply delegate, returns a result type (Freezed) for Commands to apply to BubbleResource.
- `LiveEditBubbleStateService` — emits runtime events for a bubble (e.g. for debug “model thinking” stream).
- `LiveEditSessionService` (slim) — start/end session; produces session updates (selection/draft layer updates). No UI.
- `LiveEditHitTestService` — given overlay context and point (and optionally domain), returns hit node/candidates (appScene only for cycle/hover/select).
- `LiveEditLayoutService` — bounds/layout for nodes (for overlay drawing and marquee).
- `LiveEditTreeService` — build tree representation for get_tree (if still required by PRD).

**Rules**:

- Services are called only by Commands. No direct calls from UI.
- All I/O and heavy work in Services; return immutable results (Freezed) so Commands can apply to Resources.
- Use `from_json_to_json` for any JSON in/out; `is_dart_empty_or_not` for empty checks.

**Deliverable**: Service interfaces and implementations; barrel `services/services.dart`; unit tests with mocks.

---

## Track D — Commands

**Depends on**: Track B (Resources), Track C (Services).

**Owner**: Agent D.

**Scope**: `flutter_live_edit_toolkit`: All Commands. Each Command has `execute(LiveEditContext context [, params])`. No `LiveEditController` parameter.

**Commands** (aligned to PRD; remove any that are “direct property” or out of scope):

- Start: `StartSessionCommand`, `EndSessionCommand`, `SetOverlayEnabledCommand`, `SetTargetDomainCommand`.
- Select: `SelectAtPointCommand`, `SelectNodeCommand`, `StartMarqueeCommand`, `UpdateMarqueeCommand`, `CancelMarqueeCommand`, `CommitMarqueeCommand`, `HoverAtPointCommand`, `ClearHoverCommand`, `SelectParentCandidateCommand`, `SelectChildCandidateCommand`, `CycleSelectionCandidateCommand` (appScene only in implementation).
- Bubble: `OpenAiBubbleCommand`, `HideBubbleCommand`, `SetActiveBubbleCommand`, `CollapseBubbleCommand` / `ExpandBubbleCommand`, `UpdateBubbleComposerCommand`, `SubmitAiPromptCommand`, `ApproveBubbleCommand`, `ResolveActiveBubbleCommand`; ensure empty bubble + click elsewhere closes (command or in UI using a command).
- Plan: Exposed via bubble flow (e.g. “discuss before send” produces plan; no separate command unless needed).
- Apply: `ApplyDraftCommand`, `ApplyAllBubblesCommand`, `ApplyDraftForBubbleCommand`.
- Panel: `CollapsePanelCommand`, `ExpandPanelCommand`, `TogglePanelDisplayModeCommand`, `ResizePanelCommand`, `DragPanelCommand`; navigation to bubble = `SetActiveBubbleCommand` or similar.
- Backend: `SetBackendCommand`, `SetAvailableBackendsCommand`, `SetInferenceConfigCommand`, `SetBubbleBackendCommand`, `SetBubbleInferenceConfigCommand`.
- Debug: `SetDebugModeCommand`; when debug is on, Services/agent can push “model thinking” into a Resource or stream consumed by debug UI.
- Queries (if needed): `GetTreeCommand`, `GetSelectionCommand`, `GetDraftCommand` — return data from Context Resources.

**Rules**:

- Naming: `{Action}{Resource}Command`, file `{snake_case}.cmd.dart`, class name = PascalCase of file name.
- Commands only read/write via `context.sessionResource`, `context.selectionResource`, etc., and call `context.sessionService`, `context.applyService`, etc.
- Move any “apply session update” logic into a Command or a small Service that returns updates; Command applies to Resources.

**Deliverable**: Full command set; barrel `commands/commands.dart`; unit tests with fake Context.

---

## Track E — UI (Host, Panel, Bubble, Overlay)

**Depends on**: Track B, Track D (Resources and Commands ready).

**Owner**: Agent E.

**Scope**: `flutter_live_edit_toolkit` + `live_edit_tooling_ui_kit`: Minimal UI. Split into small widgets; no single 2k+ line file.

**Structure**:

- **Host**: `FlutterLiveEditHost` — gets `LiveEditContext` from DI or `LiveEditScope`; composes overlay + child. Minimal.
- **Overlay**: `LiveEditOverlay` — overlay visibility, gesture handling; dispatches to Commands (select, marquee, hover).
- **Panel**: `LiveEditPanel` — collapse/expand, drag, resize; list of bubble statuses with navigation (invoke SetActiveBubbleCommand); uses `context.select(panelViewResource)`, `context.select(bubbleResource)`.
- **Bubble**: `LiveEditBubble` — collapse/expand, instruction field, “discuss”/submit, approve/apply, status and execution view; optional inline “model thinking” when debug mode is on (Track F).
- **Rail**: Minimal rail if needed for panel collapsed state.
- **Scope**: `LiveEditScope` / InheritedWidget or DI to provide `LiveEditContext` (and optionally Controller for external API only).

**Rules**:

- UI uses `context.read` / `context.select` on Resources; calls `SomeCommand(...).execute(context)` on gestures/callbacks.
- No business logic in widgets; no direct property editing UI.
- Philosophy: extremely minimalistic, native speed.

**Deliverable**: Host + overlay + panel + bubble widgets; theme/overlay theme minimal; app builds and overlay works with Commands.

---

## Track F — Debug mode (how model thinks)

**Depends on**: Track A (core has `LiveEditModelThinking` or equivalent), Track B (optional: a `LiveEditDebugResource` for debug state).

**Owner**: Agent F.

**Scope**: Model-thinking data and UI. When debug mode is on, show how the model thinks (reasoning trace).

**Tasks**:

1. **Core**: Ensure `LiveEditModelThinking` (or similar) is defined in Track A: e.g. steps, reasoning text, timestamps, optional role/label. Freezed + JSON.
2. **Stream / Resource**: Either push thinking events through existing `LiveEditRuntimeEvent` (e.g. kind `debug`) with payload as `LiveEditModelThinking`, or add a small `LiveEditDebugResource` that holds the current “thinking” trace for the active bubble. Service (e.g. `BubbleStateService`) receives agent output and updates Resource or emits events.
3. **UI**: In bubble or panel, when debug mode is on, show a “Model thinking” section that displays the thinking trace (list or tree of steps). Read from Resource or event stream; use `context.select(debugResource)` or listen to events.
4. **Toggle**: `SetDebugModeCommand` already in Track D; ensure it gates visibility of the thinking UI.

**Deliverable**: Debug mode toggles visibility of “how model thinks” UI; data is Freezed and serializable; no extra functionality beyond that.

---

## Track G — Integration and tests

**Depends on**: Phase 0; Tracks A–F (as they complete).

**Owner**: Agent G (or same agents in a second wave).

**Scope**: Wire-up and tests.

**Tasks**:

1. **DI**: Register all Resources and Services in app’s `dependency_injector` (or a dedicated `LiveEditDI` module). Host/Scope obtain Context from DI.
2. **flutter_test_app**: Integrate Host/Scope; provide apply delegate and backends; ensure Start, Select (appScene), Bubble, Apply, Panel, Backend flows are testable.
3. **Unit tests**: Commands (fake Context), Services (mock delegates), Resources (state transitions).
4. **Integration tests**: Harness that starts app, enables overlay, runs through one full flow (e.g. select → open bubble → submit → apply). Reuse or rewrite existing `live_edit_test.dart` / `live_edit_codex_test.dart` stubs.

**Deliverable**: App runs with live edit; integration tests pass; unit test coverage for Commands and Services.

---

## Execution order summary

| Order | Phase / Track  | Can run in parallel with                         |
| ----- | -------------- | ------------------------------------------------ |
| 1     | Phase 0        | —                                                |
| 2     | Track A (Core) | —                                                |
| 3     | Track B, C, F  | Each other (B and F depend on A; C depends on A) |
| 4     | Track D        | After B, C                                       |
| 5     | Track E        | After B, D                                       |
| 6     | Track G        | After all                                        |

**Parallel groups**:

- After Phase 0 + Track A: **B**, **C**, **F** can run in parallel.
- After B and C: **D** runs.
- After B and D: **E** runs.
- After B, C, D, E, F: **G** runs.

---

## File layout (target)

```
flutter_live_edit/
├── ROADMAP.md                    # this file
├── PRD.md                        # optional: full PRD + constraints
├── flutter_live_edit_core/
│   └── lib/
│       ├── flutter_live_edit_core.dart
│       └── src/
│           ├── live_edit_models.dart      # all Freezed models
│           ├── live_edit_models.freezed.dart
│           └── live_edit_models.g.dart
├── flutter_live_edit_toolkit/
│   └── lib/
│       ├── flutter_live_edit_toolkit.dart
│       └── src/
│           ├── commands/         # *.cmd.dart
│           ├── resources/        # *.src.dart, *.src.data.dart
│           ├── services/         # apply, bubble state, session, hit test, layout, tree
│           ├── live_edit_context.dart
│           ├── live_edit_controller_adapter.dart  # optional; no dependency in Commands
│           ├── live_edit_scope.dart
│           ├── live_edit_host.dart       # thin host
│           ├── live_edit_overlay_theme.dart
│           └── ...
├── flutter_live_edit_agent/
│   └── lib/...
├── live_edit_tooling_ui_kit/
│   └── lib/...
└── live_edit_tooling_ui_kit_playground/
    └── lib/...
```

---

## Checklist before closing the roadmap

- [ ] Phase 0 done; repo builds.
- [ ] All domain models in core are Freezed; `from_json_to_json` / `is_dart_empty_or_not` used where specified.
- [ ] Debug model `LiveEditModelThinking` (or equivalent) defined and used in debug UI.
- [ ] Resources immutable; no dependencies in Resources.
- [ ] Commands take only `LiveEditContext`; no Controller in Commands.
- [ ] Services focused; called only from Commands.
- [ ] UI minimal; selection/hover/cycle appScene only; no direct property editing.
- [ ] DI registers Resources and Services; single place for configuration.
- [ ] Integration and unit tests pass.
