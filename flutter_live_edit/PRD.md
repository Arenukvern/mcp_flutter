# Live Edit — Product Requirements & Constraints

**Narrative summary:** [USER_STORY.md](USER_STORY.md) · **Tool names & glossary:** [CONTRACT.md](CONTRACT.md) · **Package boundaries:** [BOUNDARIES.md](BOUNDARIES.md)

## Philosophy

- **Extremely minimalistic** — Only the flows below; no extra features.
- **Native speed** — Select, hover, marquee, panel drag/resize must feel instant.
- **No direct property modification** — Selection is for AI targets only; all changes go through Bubble → Plan → Apply.

---

## Main User Flows

1. **Start** — Start session (or use existing). Overlay on/off.
2. **Select** — Tap/click node; marquee (start → update → commit); hover. Cycle parent/child candidates **on appScene only**. If the same element exists on toolScene and appScene, only appScene is cyclable / hoverable / selectable.
3. **Bubble** — Collapse/expand; open AI bubble on selection; set instruction (optionally discuss before sending to create a plan); submit; optional approve/apply; see status and execution. One bubble = one AI lead agent (can spawn subagents silently). If no text is written, bubble is closable automatically when user clicks elsewhere.
4. **Plan** — User can request or view a plan (e.g. from “discuss before sending”) before applying. Plan visible in bubble/panel; apply is a separate step.
5. **Apply** — Apply current bubble or all bubbles; handle success/failure and refresh.
6. **Panel** — Collapse/expand; drag; resize; see all bubble statuses with ability to navigate to them.
7. **Backend (AI Agent)** — Set global backend (Codex CLI, Cursor, OpenCode, etc.); set per-bubble backend and inference config, or one-for-all in panel.

---

## Debug Mode

- When **debug mode** is on, the UI must show **how the model thinks** (reasoning/thinking trace from the agent).
- All model-thinking payloads are domain models: defined with **Freezed only**, serializable (e.g. `LiveEditModelThinking` with steps, reasoning chunks, timestamps).
- Debug data is pushed via runtime events or a dedicated debug Resource; UI shows it in a dedicated pane or inline in the bubble.

---

## Technical Constraints

### Models

- **Every** domain model is defined with **Freezed only**. No hand-written mutable DTOs or manual `copyWith` for domain data.
- Use **`from_json_to_json`** for JSON (de)serialization where needed (wire format, persistence, agent I/O).
- Use **`is_dart_empty_or_not`** for emptiness checks (strings, collections, optional fields) instead of ad-hoc null/empty checks.

### Architecture

- **Command–Resource pattern** + app_architecture: UI → Command → Service → Resource → UI.
- **Resources**: Hold immutable state only; no dependencies (no get_it, no Services).
- **Commands**: Take only `LiveEditContext` (Resources + Services); no `LiveEditController` parameter.
- **Services**: Called only by Commands; provide capabilities (apply, hit-test, layout, session updates, bubble state / debug events).
- **DI**: Resources and Services registered in dependency injection; single place for configuration (apply delegate, backends).

### Out of scope

- Direct property modification (no inline property editors, no “edit mode” for widget fields).
- Any feature not required by the seven user flows above.
