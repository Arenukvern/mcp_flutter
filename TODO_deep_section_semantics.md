# TODO: Deep-section semantics follow-up

## Status: root cause fixed, one residual to investigate

During E2E verification, sections past the `_ToggleSection` in the showcase
(`_SlideSection`, `_ScrollSection`, `_IterateSection`, `_DebugSection`) were
collapsing to empty semantic nodes once they scrolled into view. The
`semantic_snapshot` tool returned only 3 nodes (scrollable, Live Edit chip,
root) even though content was on screen.

## Root cause (fixed)

The slider in `_SlideSection` built with `Slider(value: state.slider, …)` where
`state.slider` defaults to `50.0`, but `Slider` defaults to `min: 0, max: 1`.
That threw `'value >= min && value <= max'` every time `_SlideSection`
rebuilt, replacing its subtree with Flutter's error widget — which in turn
torched the semantics of every sibling below it in the ListView. Integration
tests that wait on `_pumpUntil` timed out.

Fix in `flutter_test_app/lib/showcase_screen.dart`: add `min: 0, max: 100` on
the `Slider`. Also unblocks the integration test suite (now 6 passing + 1
skipped).

## Residual

The _meaning_ of the section-level Semantics wrappers still isn't great: on
the first screenful, `s_5` ends up classified as `"header"` with `actions: ["tap"]` rather than `"switch"` because the `_Section` heading's
`Semantics(header: true, …)` merges upward with the toggle row. The
interaction works — `tap_widget(s_5)` flips the toggle via
`SemanticsAction.tap` — but a future refactor of `_Section` could either:

- wrap the section body in `Semantics(container: true, explicitChildNodes: true)` so the heading can't absorb siblings, or
- drop `header: true` from the heading and rely on the identifier alone.

Not load-bearing right now — the agent still has a working ref per section.
