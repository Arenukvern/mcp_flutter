# live_edit_tooling_ui_kit

A runnable Flutter app that shows the live-edit tool layer (bubble + panel) with prefilled data.

**Purpose:** Run this app, connect live-edit (and MCP) to it, and iteratively improve the tooling UI. The same widget tree and semantics as in the main app, so selection (MCP / live-edit) targets the real bubble and panel widgets.

## Run

```bash
cd flutter_live_edit/live_edit_tooling_ui_kit
flutter run
```

On first frame the app enables the overlay, selects the target widget, opens the AI bubble, and expands the panel so the tool layer is visible and populated. You can then connect your MCP server and use live-edit tools to refine the bubble and panel UI.
