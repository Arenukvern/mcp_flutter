# live_edit_tooling_ui_kit_playground

Playground for the live-edit tooling UI kit with a **two-layer separation**:

- **Layer 1 – Main surface (dumb):** Bubble and panel are built from **fixture view models** and **stub callbacks** in `lib/src/preview/`. No `LiveEditContext`, no commands, no `LiveEditScope`. Uses the same ui_kit widgets (`PinnedBubblePill`, `PanelRail`) so it looks and feels filled but is not wired.
- **Layer 2 – Live edit (optional):** When you run with live edit, the app wraps the dumb surface in `LiveEditScope` and `FlutterLiveEditHost`; the **child** of the host is the dumb surface, and the **wired tool layer** is overlaid by the host. You edit the project (including the dumb surface code) via live edit.

**Entry points:**

- `lib/main.dart` – Live-edit mode: dumb surface as host child + wired tool layer overlay.
- `lib/main_preview.dart` – Preview only: dumb surface only, no toolkit. Run: `flutter run -t lib/main_preview.dart`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
