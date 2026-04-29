# v3.0.0 Release Audit — 2026-04-28

> Trimmed 2026-04-29 to the load-bearing decisions. The shipped status,
> per-phase task lists, and recommended-next-steps walkthrough are now
> all reflected in `CHANGELOG.md` and the v3.0.0 commit history.

## Decisions made (kept for the record)

1. **Release scope.** v3.0.0 = Playwright parity P0–P2 + the DPR
   coordinate fix. Live-edit and the tool-surface inversion ship later.
   The decision was forced by branch entanglement: `live-edit-v2-plannig`
   mixed three independent efforts (parity, in-flight selection state
   machine, large docs restructure) and only the parity slice was ready.
2. **Live-edit deferral.** `flutter_live_edit/` and all its consumers
   were excised from v3.0.0 (`d0a11c9`, `2cea690`). The
   `mcp_server_dart` package no longer pulls Flutter as a dep, which
   eliminated the `uses-material-design` warning class noted in
   earlier CLAUDE.md gotchas. The selection state-machine design at
   `todo/selection_state_machine.md` and the tool-surface inversion
   design at `todo/tool_surface_inversion.md` are preserved for
   post-v3.0.0 re-integration.
3. **Tool-surface inversion.** Originally framed as the live-edit
   carrier; T3/T5/T7 (the live-edit-shaped tasks) were dropped, the
   rest (T1/T2/T4/T6/T8/T9/T10) shipped as the v3.0.0 capability
   kernel. See CHANGELOG "MCP tool names are now prefixed by capability id".

## Deferred / nice-to-have (still relevant)

- `select_option` (P2 audit deferral) — still not shipped.
- `file_upload` — needs a host driver; deferred.
- Deep-section semantics polish — `todo/deep_section_semantics.md`.
- P3 network introspection — `todo/p3_network_introspection_deferred.md`.
- P4 tool consolidation — `todo/p4_consolidation_research_2026-04-28.md`;
  defer until usage data justifies merging tools.
