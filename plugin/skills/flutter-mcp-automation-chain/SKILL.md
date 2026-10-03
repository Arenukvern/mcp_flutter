---
name: flutter-mcp-automation-chain
description: Use this skill when wiring automation for a Flutter app — choosing the right surface (interactive MCP `fmt_*` tools, CLI one-shots, programmatic `flutter_mcp_harness` Dart scenarios, the browser CDP tier, or an external build+lifecycle runner like oka), composing the chain end-to-end, or integrating `oka` (`oka init`/`dev`/`run`, device targets, the runner-session contract, `driverForLiveSession`). Also use when the user asks which tier or mode to use, how to drive/build their app from Dart or CI without a chat round-trip, or how oka and flutter-mcp-toolkit fit together. For authoring repeatable scenarios inside this repo's showcase, use `flutter-mcp-e2e-harness`; for interactive debugging, use `flutter-mcp`.
---

<!-- @FMT_MODE_PRELUDE -->

# Flutter MCP Automation Chain

The toolkit's surfaces are **one chain, not competing products**. The app
registers `ext.mcp.toolkit.*` service extensions (`mcp_toolkit`), and every
surface drives those same extensions through the universal `AutomationDriver`
contract (`universal_automation_interface`, ADR-0038): **observe** (semantic
snapshot with refs/bounds) → **act** (tap/type/navigate) → **verify**
(snapshot again, read values). Agents learn one grammar regardless of the
target — Flutter apps, browsers (`CdpDriver`), OS-native tiers.

```text
 intentcall hints (MCP _meta)                     declarative build + lifecycle
        │                                         (oka: oka.yaml → targets)
        ▼                                                │
 ┌──────────────┐   transport over ext.mcp.toolkit.*   ▼
 │ MCP fmt_*    │ ◄── the same extensions ──►  flutter_mcp_harness
 │ CLI (fmtk)   │      (ToolkitDriver implements      Scenario / AppTargets /
 │ dynamic      │       AutomationDriver)             VmClient / LogTap
 │ app tools    │
 └──────────────┘ ◄── universal_automation_* contracts ──► CdpDriver (web)
```

## The one ownership law

**At most one owning attach session per app.** The owning session (a `flutter
run`, or an external runner's `dev` command like `oka dev`) is the only
compile-capable reload channel — a second attach on a session someone else
owns is the ADR-0014 failure mode (the second attach can kill the first).
Everything else in the chain is an **observer**: it reads the same VM service
and drives extensions, but never takes ownership. When an external runner owns
the session, it writes `.flutter_mcp/runner-session.json` (spec v2, ADR-0014)
so the toolkit and harness can find the VM and delegate reload/restart to the
owner. Absence of the file is the liveness signal.

## Pick the surface

| Need | Surface | Skill / doc |
|---|---|---|
| Chat-driven debugging ("tap X, what changed?") | MCP `fmt_*` tools | `flutter-mcp` |
| Script/CI one-shot commands (snapshot, exec, batch) | CLI (`flutter-mcp-toolkit` / `fmtk`) | [CLI vs MCP](/start_here/cli_vs_mcp) |
| Repeatable scenario as checked-in Dart, CI exit codes | `flutter_mcp_harness` | `flutter-mcp-e2e-harness` |
| Build + install + launch + process lifecycle (Android/iOS devices) | **oka** (separate repo) | this skill, oka section below |
| Browser tier (web demos, WebMCP dogfood) | `CdpDriver` over CDP | `flutter-mcp-toolkit-maintain-web` |
| Intent → driver routing without hardcoding transport | `IntentDriverRouter` + hints | this skill, intentcall section |

## First loop: interactive MCP (five minutes)

```bash
curl -fsSL https://raw.githubusercontent.com/Arenukvern/mcp_flutter/main/install.sh | bash
cd my-flutter-app
flutter-mcp-toolkit codegen-init        # adds mcp_toolkit + emits main.dart snippet
flutter-mcp-toolkit init claude-code    # or: cursor | codex | cline | all
flutter run --debug
```

The agent now inspects, taps, types, hot-reloads, and reads logs over MCP.
This is the fastest path and needs nothing else on this page.

## Second loop: own the lifecycle in Dart

For CI or test batteries that must not depend on a chat session, add the
published harness to your project and compose a scenario:

```yaml
# pubspec.yaml (hosted package)
dependencies:
  flutter_mcp_harness: ^0.1.0
```

```dart
final app = await MacosAppTarget(projectDir: '.', binaryPath: binary).launch();
final driver = ToolkitDriver(await app.vm());
final ref = await driver.findRef('login');      // snapshot refs are stable ids
// …perform click/type, re-snapshot, read values…
await app.stop();                                // scenarios stop what they started
```

Desktop targets (`FlutterRunTarget`, `BinaryAppTarget`, `MacosAppTarget`,
`WindowsAppTarget`, `ChromeAppTarget`), `Scenario` anatomy, and the
in-repo showcase launcher are covered step-by-step in
`flutter-mcp-e2e-harness` — read it before writing your first scenario.

## Third loop: device builds + lifecycle via oka

oka (separate repo, `dart pub global activate oka`) owns **build + process
lifecycle** so the toolkit can stay the observation oracle. You do **not**
need oka unless you want declarative, no-Gradle device builds and owned dev
sessions.

```bash
oka init            # scaffolds tool/oka_pipeline.dart — project-owned targets
oka build apk       # no-Gradle Android pipeline, cached artifacts
oka run device      # install → launch → failure-signature scan
oka dev             # owning dev session; agents: oka dev --watch --json (JSON events + stdin control)
```

Consuming projects compose `oka_harness` (which depends on the published
`flutter_mcp_harness`) instead of shelling out:

- `AndroidAppTarget` / `IosSimulatorAppTarget` — launch device/simulator apps
  with the same `AppTarget` contract as desktop tiers.
- `driverForLiveSession(projectDir)` — attach a driver to a session **oka
  already owns** (read the signature and `example/emulator_smoke.dart` in the
  oka repo's `packages/oka_harness/`; never launch a second owner).
- While `oka dev` owns the app, MCP `fmt_*` tools attach as usual — the
  server reads `.flutter_mcp/runner-session.json` and delegates
  reload/restart to the runner (ADR-0014 spec v2).

Division of labor (ADR-0024/0027, oka repo): oka owns compile/sync and
process lifecycle; the toolkit is the observation oracle. The CLI is
canonical; MCP is an adapter.

## intentcall hints (declarative routing)

A registered intent can carry an `IntentAutomationHint` (transport + verb +
locator) on its MCP `_meta`. `IntentDriverRouter` in `flutter_mcp_harness`
resolves that hint onto a bound `AutomationDriver`, so callers route
automation declaratively instead of hardcoding which surface performs it.
See `packages/harness/lib/src/intent_driver_router.dart` and
[IntentCall consumer guide](/intentcall/README).

## Hard boundaries

- **One owning session per app.** Observers (MCP tools, harness drivers) must
  not start a second compile-capable attach; construct `LaunchedApp` around a
  runner-owned process instead of launching a competing one.
- **The toolkit never imports a runner.** Runner identity comes from the
  discovery file, never from code (spec v2 inversion).
- **No declarative YAML scenarios here** — the document runner lives in the
  this repo (the external HS-DSL experiment, ADR-0012, is retired per
  ADR-0017); composition roots are
  consuming-project code.
- **New toolkit verbs land in `mcp_toolkit` first**; harness extensions
  mirror that list.

## Related

- `flutter-mcp` — the interactive MCP loop
- `flutter-mcp-e2e-harness` — scenario authoring, launch-path table, showcase launcher
- [The Automation Chain](/start_here/automation_chain) — first-time guide
- [Dev-session delegation roadmap](/guides/dev-session-delegation-roadmap) — spec v2 contract in full
- [E2E Scenarios](/guides/e2e_scenarios) · [CLI vs MCP](/start_here/cli_vs_mcp)

## Sources

- `decisions/0014_external_dev_sessions_runner_delegation.mdx` — runner-session contract (spec v2)
- `decisions/0015_flutter_mcp_harness_extraction.mdx` — harness extraction and boundaries
- `decisions/0012_fmtk_cli_alias_and_harness_boundary.mdx` — CLI/harness boundary
- oka repo ([github.com/Arenukvern/oka](https://github.com/Arenukvern/oka)):
  `packages/oka_harness/` (targets, `driverForLiveSession`),
  `docs/decisions/0027-oka-harness-device-targets.mdx` (hosted
  `flutter_mcp_harness` consumption), `docs/decisions/0024-declarative-test-workflows-and-agent-adapters.mdx`
  (oracle/adapter layering)
