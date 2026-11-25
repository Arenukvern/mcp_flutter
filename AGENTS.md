# Agent guide — editing `mcp_flutter`

For **using** the toolkit on a Flutter app, read [llms.txt](./llms.txt) and [docs/quickstart.mdx](docs/quickstart.mdx). This file is for agents changing **this repository**.

## Documentation router

| Need | Canonical owner |
| --- | --- |
| Charter / scope | [docs/NORTH_STAR.mdx](docs/NORTH_STAR.mdx) |
| Why (compressed) | [docs/DESIGN_FAQ.mdx](docs/DESIGN_FAQ.mdx) + [decisions/](decisions/) |
| How (contributor + agent) | [docs/DX_FAQ.mdx](docs/DX_FAQ.mdx) |
| Which FAQ to read | [.cursor/rules/faq_usage.mdc](.cursor/rules/faq_usage.mdc) |
| User onboarding | [docs/quickstart.mdx](docs/quickstart.mdx), [docs/index.mdx](docs/index.mdx) |

## Repo map

| Path | Purpose |
| --- | --- |
| `mcp_server_dart/` | MCP server + CLI (`flutter-mcp-toolkit`, `flutter-mcp-toolkit-server`) |
| `mcp_toolkit/` | Flutter app package (pub.dev) |
| `packages/core` | Shared MCP types |
| `packages/server_capability_kernel`, `packages/server_capability_core` | `fmt_*` capability implementations |
| `packages/harness/` | `flutter_mcp_harness` automation |
| `plugin/skills/` | Source skills → `skill_assets.g.dart` |
| `docs/` | docs.page site |
| `maintainers/` | Evidence, superpowers plans (not user onboarding) |
| `tool/contracts/` | CI contract scripts |

## Build / test / check

```bash
make install          # mcp_server_dart deps
make build            # compile server/CLI
make check-contracts  # full gate (needs flutter + steward)
make sync-skills      # regenerate skill_assets.g.dart
make docs-reference   # regenerate docs/reference/*.mdx
```

Focused:

```bash
cd mcp_server_dart && flutter pub get && dart test
dart analyze packages/harness && cd packages/harness && dart test
steward probe --json --profile quick
```

Never edit `pubspec_overrides.yaml`. Do not weaken test assertions.

## Runtime evidence (Flutter UI)

Flutter captures use the app render pipeline over the VM service — they work with the window in the **background**. Prefer `fmt_get_screenshots` / harness `shot.dart` over macOS screen recording for Flutter UI proof.

| Need | Use |
| --- | --- |
| Screenshot / UI state | MCP `fmt_get_screenshots` or `packages/harness/tool/shot.dart` |
| Repeatable E2E | skill `flutter-mcp-e2e-harness` |
| Web build | CDP tier in automation chain |

## Docs invariants

- **No hard-coded MCP tool counts** in prose — only in generated `docs/reference/`.
- Run `make docs-reference` when tools/CLI help change.
- `check_no_hardcoded_tool_counts.sh` enforces the rule.

## IntentCall boundary

Consumer only — architecture lives in upstream IntentCall. See `docs/intentcall/README.md` and hosted dependency gates in `make check-contracts`.

## Skill Steward

`steward doctor --json` → `steward probe --json --profile quick` before complex automation. Inspect actions with `steward action inspect <id> --json`.

## GitNexus (if available)

Index: `node .gitnexus/run.cjs analyze`. Before editing symbols: `impact({target, direction: "upstream"})`. Before commit: `detect_changes()`. Skills under `.claude/skills/gitnexus/`.