# live_edit_tooling_ui_kit

Abstract bubble and panel widgets for the live-edit tool layer. View-model and callback driven; **no dependency on** `flutter_live_edit_toolkit`.

- **Bubble:** view models and callbacks in `lib/src/bubble/`; widgets such as `PinnedBubblePill`.
- **Panel:** view models and callbacks in `lib/src/panel/`; widgets such as `PanelRail`.

The toolkit composes these widgets and wires them to commands. The **runnable app** that uses this UI kit with live editing lives in the **`live_edit_tooling_ui_kit_playground`** package.
