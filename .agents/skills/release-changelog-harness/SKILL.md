---
name: release-changelog-harness
description: Chooses ecosystem-native release and changelog tooling (Changesets, Melos, release-plz) plus binary distribution (GitHub Release tarballs, install.sh) when the product is an executable. Use for release CI, install.sh, versioning, CHANGELOGs, shipping MCP/CLI without clone, or meta repos that only ship skills via npx skills—not domain app tutorials.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.2.0"
  category: harness
paths:
  - "CHANGELOG.md"
  - ".changeset/**"
  - "package.json"
  - "pnpm-workspace.yaml"
  - "pubspec.yaml"
  - "Cargo.toml"
  - ".github/workflows/*release*"
  - ".github/workflows/*publish*"
---

# Release & changelog harness

Make **releases understandable**: every version bump has structured intent that agents and humans can read in git—not only in a maintainer’s head or a GitHub Releases textarea.

This skill is **meta harness culture** (which tool, which gates, which docs). It is **not** a full tutorial for every package manager.

## Mixture of experts — critique your idea

| Expert lens | Verdict on “use JS Changesets everywhere” |
|-------------|-------------------------------------------|
| **JS monorepo maintainer** | Strong default: `.changeset/*.md` + `changeset version` beats hand-editing five `package.json` files. |
| **Dart / Flutter publisher** | Weak fit as-is: pub uses tags + `CHANGELOG.md`; monorepos often use **Melos** `version` / `changelog`, not npm Changesets. |
| **Rust / Go shipper** | Use **release-plz**, **cargo-release**, or **git-cliff**—forcing Changesets adds alien workflow. |
| **Agent operator** | Wins when notes live as **small structured files in git** agents can read and PR—not prose-only in Slack. |
| **Multi-repo steward (`~/mcp`)** | One **legibility contract** across siblings; **different generators** per ecosystem is fine. |
| **Skill Steward charter** | Teach **when + gate + doc placement**; link to upstream docs; do not paste 200-line configs into `SKILL.md`. |

**Improved framing (use this):**

> Adopt the **release legibility contract** first; pick the **ecosystem-native generator** second (Changesets is one excellent generator for JS workspaces, not the universal hammer).

See [mixture-of-experts.md](references/mixture-of-experts.md) for extended debate and anti-patterns.

## Release legibility contract (normative)

Before picking a tool, agree the repo obeys:

1. **Notes in git** — Changelog or changeset files are versioned; not release-notes-only in a web UI.
2. **Structured contributor input** — Contributors add intent in a **fixed shape** (e.g. `.changeset/foo.md`, conventional commit scope, or ADR note)—not “bump version when you remember.”
3. **Mechanical publish path** — One documented command sequence in **DX_FAQ**; CI is the source of truth for “can ship.”
4. **Agent-readable output** — Post-release, `CHANGELOG.md` (or per-package changelogs) reflects what shipped; agents can answer “what changed in vX?”
5. **Why is recorded** — Non-obvious toolchain choice → short **ADR** or DESIGN_FAQ Q&A.
6. **Install trust matches release truth** — The latest GitHub Release, release assets, checksums, package versions, and install docs must agree; stale pinned install examples are release drift.

## Ecosystem router (default patterns)

| Signal in repo | Default tooling | Notes |
|----------------|-----------------|-------|
| `pnpm-workspace.yaml` / npm workspaces | [@changesets/cli](https://github.com/changesets/changesets) | Industry standard for JS monorepos; pair with GitHub Action. |
| Single Node package, high release cadence | [release-please](https://github.com/googleapis/release-please) or Changesets | release-please = conventional commits → PR; Changesets = explicit human/agent intent files. |
| Dart monorepo (`melos.yaml`) | [Melos](https://melos.invertase.dev/) `version` + changelog | Align with pub publish order in DX_FAQ. |
| Single Dart package | `CHANGELOG.md` + git tag + `dart pub publish` | Keep entries agent-editable markdown. |
| Rust workspace | [release-plz](https://github.com/MarcoIeni/release-plz) or cargo-release + git-cliff | Prefer automation that opens version PRs. |
| Product harness w/ binaries | release-please + tag CI + `install.sh` | **Do not** add a second version source; follow [binary-release-contract.md](references/binary-release-contract.md) |
| Meta + CLI binary (Skill Steward) | Changesets + single Release workflow + `install.sh` | Version PR updates git truth first; the release workflow tags, builds assets, creates/updates GitHub Release, and verifies latest/install trust per [ADR 0014](../../docs/decisions/0014-distribute-steward-cli-as-binary.mdx) |

Full matrix: [ecosystem-tooling.md](references/ecosystem-tooling.md). Binary/install: [binary-release-contract.md](references/binary-release-contract.md).

## When to use this skill

- “We should use Changesets like the JS community”
- Release process is unclear, versions drift, or agents can’t tell what shipped
- Adding release CI, versioning policy, or monorepo publish workflow
- Auditing whether changelog tooling matches repo archetype (`repo-quality-system-lifecycle`)

## Workflow

### 1. Classify the repo

Use `repo-quality-system-lifecycle` archetypes (app, library, CLI/tool, plugin, harness, meta/governance). **Meta and harness repos** need legibility; **app repos** need legibility **and** runtime compatibility notes.

### 2. Choose generator (ADR if non-obvious)

| Question | If yes → |
|----------|----------|
| Multiple publishable JS packages? | Changesets (default) |
| Single package, commit-msg driven releases? | release-please |
| Maintainer writes explicit release notes per PR? | Changesets |
| Pub or Cargo primary? | Ecosystem table above—not Changesets |

Record choice in `docs/decisions/NNNN-release-changelog-tooling.md` when more than one option is reasonable.

### 3. Wire harness surfaces

| Surface | Action |
|---------|--------|
| **DX_FAQ** | Memory-palace block: add changeset, version, publish, verify tag |
| **CI** | Block publish/tag if changesets/changelog policy violated; for binaries, use one release owner or an explicit workflow_run/PAT handoff |
| **AGENTS.md** | One row in doc router—no full Changesets essay |
| **CONTRIBUTING** | “Every user-facing PR adds a changeset or CHANGELOG entry” |

### 4. Minimal Changesets shape (JS monorepos and private packages)

Contributor adds:

```markdown
---
"package-name": patch
---

Short imperative summary agents can quote in release notes.
```

#### Private Packages and Public Tags
By default, Changesets ignores packages marked with `"private": true` in `package.json`. To allow version bumps for a private root package or private workspace modules, update `.changeset/config.json` to include:

```json
  "privatePackages": {
    "version": true,
    "tag": false
  }
```

Use `"tag": false` when a custom release script owns the public `vX.Y.Z` tag. Use `"tag": true` only when Changesets itself should create package-scoped tags.

Maintainer flow:

```bash
pnpm changeset          # or npx @changesets/cli
pnpm changeset version
pnpm install            # if lockfile must update
git commit -am "chore: version packages"
```

Publish: project-specific (`changeset publish`, GitHub Action, or npm provenance)—**document exact commands in DX_FAQ**, not here.

For automated Changesets releases, prefer:

```text
merge feature PR with changeset
→ CI opens/updates Version PR
→ merge Version PR
→ same Release workflow creates vX.Y.Z, builds artifacts, creates/updates GitHub Release, verifies latest release state
```

If the tag is pushed with `GITHUB_TOKEN`, do not depend on a separate `on: push: tags` workflow to build assets; GitHub suppresses recursive workflow triggers for that token.

### 5. Choose distribution surface

| Ship unit | Pattern |
|-----------|---------|
| Executable MCP/CLI | GitHub Release binaries + checksums + `install.sh` — [binary-release-contract.md](references/binary-release-contract.md) |
| Skills only | `npx skills add owner/repo` — no repo tarball for consumers |
| Libraries | pub.dev / npm / crates.io per ecosystem table |

**Skill Steward:** skills via `npx skills`; `steward_cli` precompiled AOT binaries via GitHub Releases & `install.sh` ([ADR 0014](../../docs/decisions/0014-distribute-steward-cli-as-binary.mdx)).

### 6. Verify legibility

- [ ] Agent can read “what’s unreleased” from git without GitHub API
- [ ] CI fails when a version bump lacks notes
- [ ] DX_FAQ lists commands copy-paste ready
- [ ] No duplicate version sources (e.g. hand bump + bot bump)
- [ ] If binaries: tag assets match version SSOT; latest GitHub Release points to the package version; `install.sh` defaults to latest and pinned examples use placeholders or generated checks

## Anti-patterns

| Anti-pattern | Why it hurts |
|--------------|--------------|
| Changesets in a Rust-only repo | Wrong culture; contributors ignore it |
| Changelog only on GitHub Releases | Agents in repo context miss it |
| 1,000-line release doc in AGENTS.md | Crowds task context; belongs in DX_FAQ / ADR |
| Skipping changesets “because AI will write CHANGELOG at release” | Non-deterministic; no PR-time review |
| Version bumps without consumer-facing sentence | Users and agents can’t assess upgrade risk |
| Binary Releases without changelog in git | Users see version; agents miss intent |
| Separate tag-triggered binary workflow after a `GITHUB_TOKEN` tag push | GitHub suppresses recursive workflow triggers; latest release/assets can silently lag |
| Static pinned install examples with real old versions | README/DX says one thing while GitHub Releases/install.sh say another |
| `git clone` as end-user install for a server product | Use `install.sh` + Release assets (binary release pattern) |

## Related skills

| Skill | Use for |
|-------|---------|
| `repo-quality-system-lifecycle` | Repo archetype, mechanical gates, evidence path |
| `mcp-harness-repo-maintainer` | Typed actions, probes, benchmarks, CLI/MCP parity |
| `repository-governance-lifecycle` | ADRs, DESIGN_FAQ/DX_FAQ updates, and plan hygiene |
| `skill-source-citations` | Durable release-tooling sources |

## Install

```bash
npx skills add arenukvern/skill_steward --skill release-changelog-harness
```

## Sources

[references/sources.md](references/sources.md)
