# live_edit_tooling_ui_kit_playground

Playground for the live-edit tooling UI kit with a **two-layer separation**:

- **Layer 1 – Main surface (dumb):** Bubble and panel are built from **fixture view models** and **stub callbacks** in `lib/src/preview/`. No `LiveEditContext`, no commands, no `LiveEditScope`. Uses the same ui_kit widgets (`PinnedBubblePill`, `PanelRail`) so it looks and feels filled but is not wired.
- **Layer 2 – Live edit (optional):** When you run with live edit, the app wraps the dumb surface in `LiveEditScope` and `FlutterLiveEditHost`; the **child** of the host is the dumb surface, and the **wired tool layer** is overlaid by the host. You edit the project (including the dumb surface code) via live edit.

**Entry points:**

- `lib/main.dart` – Live-edit mode: dumb surface as host child + wired tool layer overlay.
- `lib/main_preview.dart` – Preview only: dumb surface only, no toolkit. Run: `flutter run -t lib/main_preview.dart`.

## Contract scenarios (manual)

Use these after changes to `live_edit_tooling_ui_kit` or `flutter_live_edit_toolkit`:

1. **Preview-only** — `flutter run -t lib/main_preview.dart`: dumb surface renders; no overlay/toolkit errors.
2. **Live-edit host** — `flutter run` (default `main.dart`): app boots with `LiveEditScope` + host; tool layer can be toggled per app wiring.
3. **Bubble + panel chrome** — Fixture view models show bubble and panel; drag/resize handles respond (visual smoke).
4. **Two-layer separation** — In live mode, preview widgets stay the host **child**; toolkit overlay does not replace preview layout unexpectedly.
5. **Regression** — After toolkit changes, re-run (1) and (2) on one desktop target (macOS or web as available).

Cross-links: [USER_STORY.md](../USER_STORY.md), [CONTRACT.md](../CONTRACT.md).
