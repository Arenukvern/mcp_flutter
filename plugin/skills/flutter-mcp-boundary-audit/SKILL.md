---
name: flutter-mcp-boundary-audit
description: Generic contract/schema boundary audit across authoring, discovery, validation, and execute—detecting split-brain between listings and invoke paths, gateway divergence, and permissive placeholders. Use when changing tool registration, RPC/plugin registries, dynamic tools, MCP or WebMCP surfaces, CLI exec aliases, OpenAPI or JSON Schema contracts, migrators/codegen, bridge argument encoding, or platform docs that describe API contracts.
---

# Contract boundary audit

> **Skill ID:** `flutter-mcp-boundary-audit` — name is historical; content is **repository-neutral**. Same workflow applies to MCP stacks, RPC gateways, plugin registries, and OpenAPI-style contracts.

Find **split-brain** bugs: what clients **see** in listings, catalogs, or docs ≠ what **runtime** enforces on invoke—or validation exists on one gateway only.

Typical symptoms:

- Advertised `required` fields differ from what invoke accepts (empty payload succeeds, wrong keys ignored)
- Host/catalog path validates; in-process or extension path does not (or the reverse)
- Migrator or codegen rewrites entries with empty or permissive schema placeholders
- Same logical capability registered twice with different schemas (listing vs invoke, or path A vs path B)
- Stale docs claim “always permissive” or “no validation” while code is fail-closed

## When to run

| Trigger (generic) | Audit focus |
|-------------------|-------------|
| Tool/handler authoring, schema attachment at registration | Authoring → discovery payload |
| Dynamic or plugin registration on the app/runtime side | Runtime validate-before-handler |
| Server registry, forward/dispatch, catalog `*_client_tool` helpers | Registry listing + invoke |
| Host gateway (VM extension, IPC, HTTP proxy) before delegating to runtime | Host validate-before-delegate; fail-closed missing schema |
| In-process invoke (`invokeDirect`, browser hook, embedded bridge) | Same schema as listing; validate before execute |
| Entry migrator / codegen from annotated sources | Schema preservation, not permissive fallbacks |
| Shared schema module vs duplicate definitions | Dual-path parity |
| Bridge handlers, non-scalar arguments | Encoding (JSON, protobuf, etc.) vs handler expectations |
| Platform / ADR / registration docs | Stale claims vs code |

Also run after changes to **JSON Schema**, **OpenAPI** request bodies, **protobuf** RPC messages, or **plugin manifest** input shapes when multiple gateways consume the same logical tool.

## Boundary checklist

Trace **authoring → discovery → validation → execute** for every touched tool or RPC:

| Step | Question | Where to look (your repo) |
|------|----------|---------------------------|
| **Authoring** | Does the canonical input schema reach the registration/descriptor type (not dropped at a toolkit/bridge wrapper)? | Authoring layer / entry model / code generator output |
| **Authoring** | Do bridge tools encode non-scalar args consistently for legacy handlers? | Bridge helpers, adapter layers |
| **Discovery** | Does dynamic registration send the full `inputSchema` (not `{}` or implicit-any)? | App registration API, manifest emitter |
| **Discovery** | Does the host list/catalog tool expose the same schemas as the runtime registry? | List-tools handler vs app registration |
| **Server registry** | Does registry intent/metadata use real schema, not a permissive placeholder? | Registry builder, MCP tool → intent mapping |
| **Validate (registry)** | Does forward/dispatch call validate before `execute`? | Registry forward path |
| **Validate (host gateway)** | Does the host gateway validate before delegating? **Fail-closed** if schema missing? | Gateway implementation |
| **Validate (runtime)** | Does the runtime callback validate before handler? | Service extension / in-process hook |
| **Validate (wire)** | If wire args are strings/maps, is coercion applied before strict validation on paths that see wire shape? | Coercion module vs host-only typed JSON |
| **Validate (in-process)** | Does direct invoke validate before `execute`? | In-process entry invoke |
| **Validate (CLI)** | Do CLI `exec` / catalog commands use the same schema as MCP listing? | CLI dispatch vs server tools |
| **Execute** | Any `.execute(` / handler dispatch without prior `validate` in production code? | Grep (below) |
| **Migrator** | Does migration preserve primitive/required/additionalProperties from source schema? | Migrator, codegen |
| **Docs** | Do platform/registration docs match actual fail-closed behavior? | Platform doc, ADRs |

## Gateway divergence

Same logical tool may flow through **different gateways**—each must agree on schema and validation order:

```text
Authoring (entry / descriptor)
    ├─► Runtime registration ──► extension/callback ──► handler
    ├─► In-process register (WebMCP / embedded) ──► invokeDirect
    └─► Host list/catalog ──► catalog invoke ──► host gateway ──► runtime
```

| Gateway role | Must validate before | Fail if schema missing? |
|--------------|----------------------|-------------------------|
| Runtime callback (extension, plugin hook) | handler | yes (production tools) |
| Registry forward | `execute` / handler | yes |
| Host gateway (proxy to runtime) | delegate call | yes |
| In-process invoke | `execute` | yes |
| Catalog / fmt_* / CLI wrapper | forward to runtime | yes (same as listing) |
| CLI `exec` | command dispatch | yes |

**Red flag:** validation only in tests, only on the catalog path, or only on listing—not on the path your change actually uses.

### Wire coercion (when applicable)

Some stacks deliver **string-key maps** on the wire (VM service extensions, JSON-RPC with loose typing). Separate concerns:

| Mechanism | Role |
|-----------|------|
| Coerce-for-schema | Property-type coercion from wire strings before strict schema validation |
| Handler-side wire parsers | Optional when handlers still read raw wire maps |
| Outbound wire encoding | Handler args → wire-safe representation |

Re-audit **host gateway** vs **runtime callback** if you add coercion on one side only—hosts that expect typed JSON must not assume runtime already coerced (and vice versa).

## Dual-path parity

One logical capability often exists **twice**:

| Path | Typical role | Listing / invoke |
|------|--------------|------------------|
| **Runtime / app dynamic** | Registered in the running app or plugin host | Extension name, dynamic registry |
| **Host catalog** | Server-side MCP tools, CLI aliases, OpenAPI routes | Prefixed or bare names on wire |

For each shared tool, compare:

- `required` keys
- `additionalProperties: false` (or equivalent strictness)
- Host-only fields (e.g. `connection`) present on one path only
- Property types / enums
- Default values and coercion behavior

Document intentional deltas in your **platform contract doc** (not only in tests).

## Red-flag grep

Run from **your repository root**. Adjust globs to your languages and package layout.

```bash
# Empty or permissive advertised schemas (JSON Schema style)
rg "inputSchema:\s*const\s*\{\s*'type':\s*'object'" --glob "*.dart" -g '!test/fixtures/**' -g '!**/after_*.dart'
rg '"type"\s*:\s*"object"\s*,\s*\}' --glob "*.{dart,ts,js,json,yaml}"
rg "_emptyObjectSchema|additionalProperties:\s*true" --glob "*.{dart,ts,js}"

# OpenAPI / generic permissive bodies
rg "additionalProperties:\s*true" --glob "*.{yaml,yml,json}"
rg "schema:\s*\{\s*\}" --glob "*.{yaml,yml}"

# Execute without validate (review each hit; exclude tests/fixtures)
rg "\.execute\(" --glob "*.{dart,ts,js}" | rg -v "validate|test/|_test\.|\.test\."

# Direct invoke bypass
rg "invokeDirect|invoke_direct|directInvoke" --glob "*.{dart,ts,js}"
# Manual review: validate appears before execute on each path

# Permissive registry placeholders
rg "emptyObjectSchema|empty_object_schema|placeholder.*schema|inputSchemaFrom" --glob "*.{dart,ts,js}"

# Migrator stripping schemas
rg "inputSchema|input_schema" --glob "*migrate*"

# Duplicate registration (e.g. JS + native)
rg "registerTool|register_tool" --glob "*.{dart,ts,js}"

# Stale “always permissive” docs
rg -i "permissive|additionalProperties:\s*true|no validation|accepts anything" --glob "*.md"

# Bridge / JSON args
rg "jsonEncode|JSON\.encode|serialize.*argument" --glob "*{bridge,entry,adapter}*"
```

Add project-specific patterns after completing [Adapting to your repo](#adapting-to-your-repo).

## E2E proof

Run **your** integration tests that cover listing + invalid invoke (not a specific app path).

Checklist:

1. List tools/resources (or OpenAPI GET) shows `required` and strict `additionalProperties` where intended.
2. Invoke with missing `required` → structured failure (`ok: false`, 4xx, or validation error)—**before** handler side effects.
3. Invoke with extra properties when schema is strict → same failure mode.
4. If dual paths exist, repeat on **both** catalog and runtime registration names.

Optional: schema parity unit tests comparing shared module vs duplicate definitions (no device required).

## Report template

```markdown
## Finding: [title]
- **Severity**: P0 | P1 | P2
- **Boundary**: authoring | discovery | validation | execute
- **Gateway**: runtime-callback | registry | in-process | host-gateway | cli | migrator | docs
- **Files**: ...
- **Symptom**: clients/docs see X; runtime does Y
- **Fix**: ...
- **Proof**: test name or grep command
```

## Tracker (optional)

If your repo uses a superpowers/tracker or hardening program, record new findings there or as issues—do not reopen completed items unless regression.

## Adapting to your repo

Before auditing, fill this map (keep in audit notes or PR description):

| Role | Your location | Notes |
|------|---------------|--------|
| **Authoring** | e.g. entry model, OpenAPI spec, `@Tool` annotations | Where canonical schema is defined |
| **Discovery** | e.g. `registerDynamics`, plugin manifest, MCP `tools/list` | What clients read |
| **Registry / catalog** | e.g. dynamic registry, server tool table | Listing vs invoke entry points |
| **Host gateway** | e.g. VM extension proxy, API gateway, sidecar | Validates before delegate? |
| **Runtime callback** | e.g. service extension, plugin host RPC | Validates before handler? |
| **In-process invoke** | e.g. WebMCP, embedded JS bridge | Same as `tools/list`? |
| **CLI** | e.g. `exec`, bare vs prefixed aliases | Same schema as MCP? |
| **Shared schema module** | e.g. `interaction_input_schemas`, OpenAPI components | Single source of truth? |
| **Migrator / codegen** | e.g. `migrate agent-entries` | Preserves required/properties? |
| **Platform doc** | e.g. `AGENTKIT_PLATFORM.md`, README contract section | Matches fail-closed code? |

**Checklist**

- [ ] Map tool registration path (authoring → discovery).
- [ ] Map **listing** gateway vs **invoke** gateway(s); list every hop.
- [ ] Map schema representation (JSON Schema maps, OpenAPI, protobuf, Dart `ObjectSchema`, etc.).
- [ ] Add 2–3 repo-specific red-flag greps (permissive placeholder, your invoke helper name).
- [ ] Identify dual-path tools; note shared module or document intentional split.
- [ ] Run integration test or manual proof for one strict tool on every gateway you touched.

## Deep reference

Worked example (mcp_flutter), file map, and regression patterns: [reference.md](reference.md)

## Related skills (mcp_flutter)

When working in this monorepo only:

- `flutter-mcp-toolkit-custom-tools` — authoring entries
- `flutter-mcp-toolkit-agentkit-migration` — migrate agent-entries
- `flutter-mcp-toolkit-maintain-web` — WebMCP / in-process invoke
- `flutter-mcp-cli-runtime-validation` — runtime validate-runtime
