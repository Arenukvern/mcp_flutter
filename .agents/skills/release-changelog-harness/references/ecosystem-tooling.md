# Ecosystem tooling matrix

Pick **one primary generator** per repo. Link upstream docs; do not duplicate them here.

## JavaScript / TypeScript

| Tool | Best for | Agent hook |
|------|----------|------------|
| **Changesets** | Monorepos, explicit release notes per change | Add/edit `.changeset/*.md` in PR |
| **release-please** | Conventional commits, single or mono repo | Ensure commit messages match parser |
| **semantic-release** | Fully automated npm publish pipelines | Less human intent per PR—document trade-off in ADR |

**CI pattern:** run `changeset status` or equivalent on PR; publish workflow on `main` tag or `changeset publish`.

## Dart / Flutter

| Tool | Best for | Agent hook |
|------|----------|------------|
| **Melos** | Multi-package Dart repos | `melos version`, changelog commands |
| **Manual CHANGELOG + tag** | Single package | Edit `CHANGELOG.md` section `[Unreleased]` |
| **Custom scripts** (product harness) | product-style plugin.json + binaries | [binary-release-contract.md](binary-release-contract.md) — extend, don’t replace |

## Rust

| Tool | Best for | Agent hook |
|------|----------|------------|
| **release-plz** | Crates.io workspace, PR-based releases | Review release PR body |
| **cargo-release** | Maintainer-driven crate publish | Document in DX_FAQ |
| **git-cliff** | Changelog from conventional commits | Commit message discipline |

## Meta / docs / skills

| Tool | Best for | Agent hook |
|------|----------|------------|
| **Root CHANGELOG.md** | skill_steward, small meta repos | One bullet per merged PR affecting consumers |
| **ADR + tag** | Infrequent meta releases | ADR notes breaking changes to install paths |

## Cross-cutting CI checks

```text
PR opened → contributor added structured release note?
merge to main → version/changelog coherent?
tag/publish → artifacts match changelog?
tag/publish → binaries checksum-verified and version-aligned?
```

Implement with your stack’s workflow file; keep command names in **DX_FAQ**, not in skills.

## Distribution surfaces (not generators)

| Consumer gets | Mechanism | Reference |
|---------------|-----------|-----------|
| MCP/CLI binary | GitHub Releases + `install.sh` | [binary-release-contract.md](binary-release-contract.md) |
| Skills | `npx skills add owner/repo` | vercel-labs/skills |
| Dart libs | `dart pub publish` | Melos / manual CHANGELOG |
| Meta steward CLI | GitHub Releases + `install.sh` | [binary-release-contract.md](binary-release-contract.md) per [ADR 0014](../../../docs/decisions/0014-distribute-steward-cli-as-binary.mdx) |

## Sibling consistency

| Repo Type | Typical release face |
|-----------|------------------------|
| **Product MCP** | release-please + Release tarballs + `install.sh` |
| **Platform Libs** | pub/npm publish + changelog per package |
| Meta Steward | Changesets + tag CI + `install.sh` |
| **CLI Harness** | fixtures + package versions; binaries when standalone CLI ships |

Align **wording** (“what changed for agents?”) across siblings; **do not** force one npm tool on all.
