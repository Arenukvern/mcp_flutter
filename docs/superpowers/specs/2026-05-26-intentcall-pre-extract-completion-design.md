# intentcall Phase 6 — Pre-extract completion (design)

**Status:** Delivered in-repo (2026-05-26); Bar **D** met.  
**Bar:** **D** — Strict (**B**) + Swift/XML emitters; **skip Gemma product only**; **hard cut** on legacy APIs with documented migration + CLI/MCP migration tools + updated skills.  
**Branch policy:** All work on `feat/intentcall-phase1-3` (or successor) until gate passes; **no standalone repo extract until Phase 7.**

**References:** [2026-05-25-intentcall-design.md](2026-05-25-intentcall-design.md), [phase5 hardening](2026-05-25-intentcall-phase5-hardening-design.md), [tracker](../tracker/intentcall-rollout.yaml)

---

## Summary

Phase 6 finishes intentcall **inside mcp_flutter** so the codebase matches the approved design spec: one registry invoke path, no lingering `MCPCallEntry` public API, real platform emitters, contract tests, and operator-facing migration. After the Phase 6 gate (`program.status: complete_in_repo`), Phase 7 may extract packages to a standalone monorepo.

**Phase 8 (in-repo product, 2026-05-26):** Operator tools deferred from the phase 6 narrative shipped in a follow-up gate — `init intentcall-platform`, `intentcall_platform` Flutter plugin + `app_links`, `fmt_migrate_agent_entries`, CI `codegen sync --check` on `flutter_test_app`. Tracker: `phase8` → `program.status: complete_in_repo_product`. See [product closure](../closure/2026-05-26-intentcall-product-complete-in-repo.md).

---

## Merge bar (Bar D — explicit)

| Included | Excluded |
|----------|----------|
| Full removal of public `MCPCallEntry` API (hard cut) | `flutter_gemma` product wiring in shipping app |
| All in-repo call sites migrated to `AgentCallEntry` | Standalone intentcall monorepo extract (Phase 7) |
| Server: ≥1 `fmt_*` tool via `@AgentTool` codegen in capability core | Keeping `@Deprecated` `MCPCallEntry` bridge “for compatibility” |
| Contract tests: registry ↔ MCP (fmt + dynamic tool + one resource) | Soft deprecation period with dual APIs |
| Swift + XML emitters from `agent_manifest.json` | Gemma adapter hot-sync product work |
| Registry-backed resource template for `visual://localhost/app/errors/{count}` (or spec’d exception removed) | |
| Public re-export shim removal (semver bump) | |
| **Migration:** CHANGELOG + migration guide + **CLI** + **MCP tool** | |
| **Skills:** new migration skill + update custom-tools / debug / repo-maintainer | |
| **`intentcall_platform`:** own emitters + sync (no manual copy) | HarmonyOS NEXT / Intents Kit |
| **Web (priority):** WebMCP runtime + PWA manifest emitters | |

---

## Architecture (unchanged)

```text
Capabilities / app entries (AgentCallEntry)
        → RegisteredAgentIntent → AgentRegistry
        → AgentRuntime.adapters[] → McpPublishAdapter → dart_mcp
```

Phase 6 does **not** redesign this graph; it removes bypasses, completes emitters, and migrates authoring surfaces.

---

## Sub-phases

### 6a — Server registry completeness

**Goals**

- Eliminate undocumented MCP bypasses on the hot path (dynamic and static).
- Implement **registry-backed** read for `visual://localhost/app/errors/{count}` (URI template → intent with `count` argument), removing the Phase 5-B `addResourceTemplate`-only exception unless impossible—then document a single permanent exception in this spec (prefer implementation).
- Wrap dynamic intents with connection policy at the intent layer (already started in 5-B; verify no duplicate handlers).

**Validation**

- `dart test` host, registry, dynamic registry integration tests
- Manual: `fmt_client_resource` / read resource for errors template

---

### 6b — Hard cut: `MCPCallEntry` removal

**Goals**

- Delete `MCPCallEntry` type, `MCPCallEntryAgentBridge`, and `@Deprecated` factories from `mcp_toolkit`.
- Replace with **`AgentCallEntry`** only (from `intentcall_core`, exported by `mcp_toolkit`).
- Migrate **all in-repo** consumers:
  - `flutter_test_app`
  - `mcp_toolkit` toolkits (`interaction_toolkit`, `permission_toolkit`, extensions, binding, `agent_client_install`)
  - `mcp_toolkit` examples
  - Tests
- Update `AgentClientInstall` to `Set<AgentCallEntry>` (no MCP alias).

**Breaking change policy**

- **Semver:** major bump for `mcp_toolkit` (and server if CLI contract changes).
- **CHANGELOG:** dedicated “intentcall Phase 6 / MCPCallEntry removal” section with before/after snippets.
- **No** `typedef MCPCallEntry = AgentCallEntry` shim in public API.

---

### 6c — Server codegen (prove path)

**Goals**

- One **`fmt_*`** capability tool generated via `@AgentTool` in `server_capability_core` (or one capability package), committed `.g.dart`, registered through existing `ToolRegistration` / host path.
- Document how to add more generated tools in capability README.

**Validation**

- `dart test` for capability package + e2e host invokes generated tool name

---

### 6d — Platform sync (`intentcall_platform`, own emitters — Option 1)

**Principle:** `agent_manifest.json` is canonical. **`codegen sync`** writes into the Flutter project tree; **`init intentcall-platform`** injects Gradle/Xcode/`index.html` hooks once. No manual copy into Xcode or Android Studio.

**Package:** `intentcall/packages/intentcall_platform/` — emitters, `AgentPlatformBuilder` (build_runner), CLI sync, thin `intentcall_platform` Flutter plugin (URI / invoke route).

#### Platform scope

| Platform | Emitter / adapter | Notes |
|----------|-------------------|--------|
| **Web** (highest priority) | See below — dual surface | WebMCP + PWA manifest |
| **Android** | `AndroidShortcutsXmlEmitter` | Covers **Xiaomi HyperOS**, Huawei **Android APK**, stock Android — same `shortcuts.xml`; OEM quirks = docs only |
| **iOS** | `AppleSwiftAppIntentsEmitter` | Compile-time Swift; Xcode Run Script |
| **macOS** | Same Swift emitter → `macos/Runner/Generated/` | App Intents on desktop where supported |
| **Linux** | `LinuxDesktopEntryEmitter` + xdg register script | `x-scheme-handler` + `.desktop` |
| **Windows** | `WindowsProtocolEmitter` | MSIX `protocol_activation` and/or registry script |
| **HarmonyOS NEXT** | — | **Out of scope** (skip entirely) |

#### Web — dual bootstrap (**decision C**)

Web has **two** agent surfaces; both map to the same Dart handlers:

1. **WebMCP (runtime, primary for in-browser agents)**  
   - API: `navigator.modelContext.registerTool` / `unregisterTool` (W3C CG draft; Chrome 146+).  
   - Existing: `intentcall_webmcp` / `WebMcpPublishAdapter` + registry hot-sync.  
   - **Generated:** `web/intentcall_webmcp.generated.js` — registers all tools on load with feature-detect (`'modelContext' in navigator`).  
   - **Use when:** static pages, non-Flutter web, or explicit JS bootstrap in `index.html`.

2. **Dart bootstrap (Flutter web apps)**  
   - **`dart:js_interop`** (or package `web`) from `main()` / `AgentClientInstall` web path: calls `registerTool` for each `AgentCallEntry` after registry is ready.  
   - **Use when:** standard Flutter web; keeps tooling in Dart only.

3. **PWA manifest (build-time, OS install surface)**  
   - **`WebManifestEmitter`:** patch `web/manifest.json` with `shortcuts[]` and `protocol_handlers[]` per tool (e.g. `url: "/agent/invoke?name=app_cart_total"`).  
   - Flutter route reads query → same handler as WebMCP `execute`.  
   - Complements WebMCP; does not replace it (agents in Chrome discover runtime tools, not manifest).

**One-time init:** snippet in `web/index.html` loads JS bundle; `flutter-mcp-toolkit init intentcall-platform` documents both paths.

#### Native mobile / desktop

- **Apple:** Swift `AppIntent` + `AppShortcutsProvider` + `IntentCallNativeBridge.swift` → deep link `intentcall://invoke/<qualifiedName>` or plugin channel.  
- **Android:** `res/xml/intentcall_shortcuts.xml` + manifest meta-data; Gradle `preBuild` runs `codegen sync --platform android`.  
- **Linux / Windows:** packaging files + `app_links` / protocol registration; plugin dispatches to Dart.

#### CLI

```bash
flutter-mcp-toolkit codegen sync --platform web,android,ios,macos,linux,windows
flutter-mcp-toolkit codegen sync --check   # CI drift gate
flutter-mcp-toolkit init intentcall-platform # one-time hooks
```

#### Validation

- Golden tests per emitter (web manifest JSON, JS bundle shape, XML, Swift snippet).  
- `cd intentcall && dart test packages/intentcall_platform`  
- Example Flutter app: web build registers tools in DevTools / `modelContextTesting` where available.

**Non-goals (6d)**

- HarmonyOS NEXT, Intents Kit, ArkTS bridges, `hadss_intents` integration  
- Full Xcode/Gradle project scaffolding beyond hook injection  
- App Store / Play submission automation  
- Gemma / `flutter_gemma` product wiring  

**OEM note (Xiaomi / Huawei Android):** no separate emitter; optional `docs/platform-notes/android-oem.md` for HyperOS background/autostart only.

---


### 6e — Contract & integration tests

**Goals**

- `packages/intentcall_testing` (or `mcp_server_dart/test/contract/`):
  - Same `AgentArguments` → same `AgentResult` for: one `fmt_*` tool, one dynamic tool (fake registry), one static resource URI.
  - MCP adapter round-trip: `CallToolResult` / `ReadResourceResult` ↔ `AgentResult` mappers.
- CI matrix entry: `dart test` contract suite + full `mcp_server_dart` test.

---

### 6f — Migration operator surfaces

**Goals**

**Documentation**

- `docs/start_here/migration_intentcall_phase6.md` (or extend `migration_v2_to_v3.mdx`): MCPCallEntry → AgentCallEntry tables, bootstrap changes, breaking exports.

**CLI** (`mcp_server_dart/bin/flutter_mcp_toolkit.dart`)

- Subcommand: `migrate agent-entries` (aliases: `migrate mcp-call-entry`)
  - Input: Dart file or directory
  - Output: stdout diff or `--write` in-place
  - Transforms: `MCPCallEntry.tool` → `AgentCallEntry.tool`, `.resource` → `.resource`, `Set<MCPCallEntry>` → `Set<AgentCallEntry>`, common import fixes
  - `--check` only (exit 1 if would change)
  - Document limitations (extension types wrapping MCPCallEntry need manual follow-up)

**MCP tool** (server capability)

- `fmt_migrate_agent_entries` (or under existing codegen capability): accepts `files[]` or `projectRoot`, returns migration report JSON (per-file status, suggested patches or applied when `apply: true` via VM not required—operate on host filesystem paths agent provides). Safe default: **report-only**; `apply` requires explicit flag.

**Validation**

- Tests for migrator on fixture files in `mcp_server_dart/test/fixtures/migrate/`

---

### 6g — Skills & bundled assets

**Goals**

- **New skill:** `plugin/skills/flutter-mcp-toolkit-intentcall-migration/SKILL.md` — when to run CLI vs MCP migrate, hard cut timeline, AgentCallEntry patterns.
- **Update skills:**
  - `flutter-mcp-toolkit-custom-tools` — AgentCallEntry-only examples
  - `flutter-mcp-toolkit-debug` — reference registry invoke / fmt tools
  - `flutter-mcp-toolkit-repo-maintainer` — Phase 6 release checklist, skill_assets regen
- Regenerate `mcp_server_dart/lib/src/skill_assets.g.dart` from plugin skills (existing pipeline).
- Update `server_instructions.dart` / MCP server instructions string.

**Validation**

- Grep gate in CI or maintainer script: no `MCPCallEntry` in `plugin/skills/` or `skill_assets.g.dart` except migration skill “before” examples.

---

### 6h — Shim removal & program gate

**Goals**

- Remove redundant public re-exports from `mcp_toolkit` that duplicate `intentcall_*` (keep intentional `export intentcall_core` / `intentcall_schema` if still the single import story—document the allowed surface).
- Tracker: `program.status: complete_in_repo`, `active_phase: null`
- Closure: `docs/superpowers/closure/2026-05-26-intentcall-program-complete-in-repo.md`
- Rollout doc: Phase 6 `done`, Phase 7 extract `pending`

**Validation (full gate)**

```bash
make check-intentcall-integration
make dogfood-eval-static
# Runtime: make web-showcase → export WS_URI → make dogfood-eval
```

---

## Key design decisions

| Topic | Decision |
|-------|----------|
| Deprecation vs hard cut | **Hard cut** in code; migration via docs + CLI + MCP tool |
| Gemma | **Out of scope** — `intentcall_gemma` stays example-only |
| Swift/XML | **In scope** — emit real artifacts, not JSON-only |
| Resource templates | **Implement** registry-backed template; drop `addResourceTemplate` exception |
| Migration MCP tool | Report-only default; `apply` explicit |
| Semver | Major `mcp_toolkit` bump minimum |
| Extract | **Phase 7** only after 6h gate |
| Platform emitters | **Option 1** — own emitters in `intentcall_platform` |
| Web bootstrap | **C** — generated JS + Dart `js_interop` path |
| HarmonyOS NEXT | **Skipped** — not in Phase 6 or 7 prerequisite |
| Xiaomi / Huawei | **Android emitter only** — same XML as AOSP |

---

## File map (expected touch)

| Area | Paths |
|------|--------|
| Client API | `mcp_toolkit/lib/src/mcp_models.dart`, `mcp_call_entry_bridge.dart` (delete), binding, toolkits, `agent_client_install.dart` |
| Test app | `flutter_test_app/lib/**` |
| Server | `flutter_inspector.dart`, `dynamic_registry_integration.dart`, capability core codegen |
| Platform sync | `intentcall/packages/intentcall_platform/`, `intentcall/packages/intentcall_apple/`, `intentcall/packages/intentcall_android/`, `intentcall/packages/intentcall_webmcp/` |
| Web artifacts | `web/manifest.json`, `web/intentcall_webmcp.generated.js`, `web/index.html` snippet |
| CLI | `mcp_server_dart/bin/flutter_mcp_toolkit.dart`, `lib/src/cli/migrate_agent_entries_command.dart` |
| MCP migrate tool | new capability or `server_capability_core` command |
| Docs | `CHANGELOG.md`, `docs/start_here/migration_intentcall_phase6.md` |
| Skills | `plugin/skills/flutter-mcp-toolkit-*`, `skill_assets.g.dart` |
| Tests | contract tests, migrate fixtures |

---

## Phase 7 preview (out of scope)

- `intentcall` standalone repo, pub.dev publish, path dep → version dep in mcp_flutter
- Consumer CI split

---

## Open questions (resolved by Bar D)

| Question | Resolution |
|----------|------------|
| Merge bar | D = B + Swift/XML, skip Gemma only |
| MCPCallEntry | Remove entirely |
| Migration | CLI + MCP + docs + skills |
| Web bootstrap | **C** — JS generated bundle + Dart interop |
| HarmonyOS NEXT | **Skipped** |

---

## Approval

Bar **D** approved 2026-05-26. Platform **Option 1** + Web **C** + skip HarmonyOS NEXT approved 2026-05-26.

**Implementation plan (archived):** [2026-05-26-intentcall-phase6-pre-extract.md](../plans/archive/2026-05-26-intentcall-phase6-pre-extract.md). **Forward work:** [WHATS_NEXT](../WHATS_NEXT.md) · [Phase 7 extract](../plans/2026-05-27-intentcall-phase7-extract.md). Integration hardening (archived): [integration completion plan](../plans/archive/2026-05-26-intentcall-integration-completion-next.md).
