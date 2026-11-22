---
name: flutter-mcp-toolkit-repo-maintainer
description: >-
  Maintain mcp_flutter releases, CHANGELOG, version pins, docs, and CI.
  Use when cutting a release, editing CHANGELOG.md, bumping VERSION, running
  release-please, sync-skills, check-contracts, or updating install/docs for
  npx skills and flutter-mcp-toolkit init.
---

<!-- @FMT_MODE_PRELUDE -->

# flutter-mcp-toolkit repo maintainer

Golden path for **this repository** (not end-user Flutter apps). Prefer
release-please on `main`; use manual steps only when the Release PR path is blocked.

## When to use

- Cutting a release or promoting `## [Unreleased]` in CHANGELOG.md
- Adding/editing contributor docs, AI agent install docs, or plugin skills
- Verifying version sync or skill asset drift before merge
- Troubleshooting release-please, `release.yml` binaries, or `install.sh` version pins

## Version touchpoints (must match root `VERSION`)

| File                                                                                                                                                                           | Field                                                                                                                                                 |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| [VERSION](https://github.com/Arenukvern/mcp_flutter/blob/main/VERSION)                                                                                                         | repo pin                                                                                                                                              |
| [plugin/EXPECTED_SERVER_VERSION](https://github.com/Arenukvern/mcp_flutter/blob/main/plugin/EXPECTED_SERVER_VERSION)                                                           | installer pin                                                                                                                                         |
| [packages/core/lib/src/runtime_version.dart](https://github.com/Arenukvern/mcp_flutter/blob/main/packages/core/lib/src/runtime_version.dart)                                   | `kFlutterMcpVersion` (`x-release-please-version`)                                                                                                     |
| [packages/server_capability_core/lib/src/fmt_capability.dart](https://github.com/Arenukvern/mcp_flutter/blob/main/packages/server_capability_core/lib/src/fmt_capability.dart) | `version` getter                                                                                                                                      |
| [mcp_server_dart/pubspec.yaml](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_server_dart/pubspec.yaml)                                                               | `version:`                                                                                                                                            |
| [mcp_toolkit/pubspec.yaml](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_toolkit/pubspec.yaml)                                                                       | `version:`                                                                                                                                            |
| [packages/core/pubspec.yaml](https://github.com/Arenukvern/mcp_flutter/blob/main/packages/core/pubspec.yaml)                                                                   | `version:`                                                                                                                                            |
| [packages/server_capability_kernel/pubspec.yaml](https://github.com/Arenukvern/mcp_flutter/blob/main/packages/server_capability_kernel/pubspec.yaml)                           | `version:` + same-train dependency constraints                                                                                                        |
| [packages/server_capability_core/pubspec.yaml](https://github.com/Arenukvern/mcp_flutter/blob/main/packages/server_capability_core/pubspec.yaml)                               | `version:` + same-train dependency constraints                                                                                                        |
| [plugin/.cursor-plugin/plugin.json](https://github.com/Arenukvern/mcp_flutter/blob/main/plugin/.cursor-plugin/plugin.json)                                                     | `version`                                                                                                                                             |
| [plugin/.codex-plugin/plugin.json](https://github.com/Arenukvern/mcp_flutter/blob/main/plugin/.codex-plugin/plugin.json)                                                       | `version`                                                                                                                                             |
| [plugin/.claude-plugin/plugin.json](https://github.com/Arenukvern/mcp_flutter/blob/main/plugin/.claude-plugin/plugin.json)                                                     | `version`                                                                                                                                             |
| [.claude-plugin/marketplace.json](https://github.com/Arenukvern/mcp_flutter/blob/main/.claude-plugin/marketplace.json)                                                         | `plugins[0].version`                                                                                                                                  |
| [.release-please-manifest.json](https://github.com/Arenukvern/mcp_flutter/blob/main/.release-please-manifest.json)                                                             | `"."` key                                                                                                                                             |
| [mcp_server_dart/lib/src/skill_assets.g.dart](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_server_dart/lib/src/skill_assets.g.dart)                                 | **generated** — embeds `plugin/.cursor-plugin/plugin.json`, `plugin/.codex-plugin/plugin.json`, `plugin/mcp.json`, and all `plugin/skills/*/SKILL.md` |

After any version bump: run `make sync-version`, then `make sync-skills`, then `make check-contracts` (includes `check_version_sync.sh` and `check_skill_assets_drift.sh`). `tool/release/sync_version.sh` derives all version touchpoints from root `VERSION`.

**Video (separate repo):** [flutter_mcp_video](https://github.com/Arenukvern/flutter_mcp_video) — not maintained in this plugin tree. The external `flutter_harness` repo is retired (ADR-0017); its scenario layer was never migrated.

## Changelog workflow

1. Add user-facing notes under `## [Unreleased]` in [CHANGELOG.md](https://github.com/Arenukvern/mcp_flutter/blob/main/CHANGELOG.md) (Keep a Changelog sections: Added, Changed, Fixed, Documentation).
2. Use conventional commit titles on `main` (`feat:`, `fix:`, `docs:`) so release-please can aggregate.
3. Do **not** edit the plan file in `.cursor/plans/`.

### Markdown lint (MD052)

Keep a Changelog **requires** version headings like `## [3.0.1]`. Linters treat `[3.0.1]` as an undefined **reference link** (MD052: "No link definition found").

- **Do not remove** the file-top `<!-- markdownlint-disable MD052 -->` in CHANGELOG.md (release-please must keep it when prepending sections).
- In bullet text, use **backticks** for code identifiers: `` `AgentCallEntry` ``, not `[AgentCallEntry]`.
- Before merge: `bash tool/contracts/check_changelog_markdown.sh` (also in `make check-contracts`).

## Automated release (preferred)

```mermaid
flowchart LR
  main[merge_to_main] --> eng[dart_changesets.yml]
  eng --> pr[changesets/version-packages_PR]
  pr --> sync[dart_changesets_sync_versions.yml]
  pr --> assets[release_pr_sync_skills.yml]
  pr --> merge[version_PR_merge]
  merge --> tags[per-package_tags]
  tags --> pub[dart_changesets_publish.yml_pubdev]
  tags --> rel[release.yml_binaries_server_tag]
```

1. Merge PRs to `main` with conventional commits; add `.changesets/*.md` intent files (verbatim upstream-changesets format) to queue package bumps.
2. **version PR:** [dart_changesets.yml](https://github.com/Arenukvern/mcp_flutter/blob/main/.github/workflows/dart_changesets.yml) assembles/updates the `changesets/version-packages` PR ("chore: version packages") from pending intent files.
3. **version sync:** [dart_changesets_sync_versions.yml](https://github.com/Arenukvern/mcp_flutter/blob/main/.github/workflows/dart_changesets_sync_versions.yml) runs `tool/release/sync_version.sh` on the version PR (root `VERSION`, mcpb manifest, `server.json`).
4. **skill assets + docs reference:** [release_pr_sync_skills.yml](https://github.com/Arenukvern/mcp_flutter/blob/main/.github/workflows/release_pr_sync_skills.yml) regenerates on the version PR; [regen_surfaces.yml](https://github.com/Arenukvern/mcp_flutter/blob/main/.github/workflows/regen_surfaces.yml) is the post-merge drift safety net. If **skill-assets-drift** still fails, run `make sync-skills` locally and push.
5. Review VERSION, CHANGELOG, pubspecs, plugin pins in that PR → merge.
6. The merge pushes one tag per released package (`<package>-v<semver>` via `RELEASE_PLEASE_TOKEN`) and starts one [dart_changesets_publish.yml](https://github.com/Arenukvern/mcp_flutter/blob/main/.github/workflows/dart_changesets_publish.yml) run per tag — concurrent runs converge on pub.dev dependency-floor visibility through the upstream waiter; no manual ordering.
7. The server tag's run chains [release.yml](https://github.com/Arenukvern/mcp_flutter/blob/main/.github/workflows/release.yml) binaries: tarballs + `flutter-mcp-toolkit.mcpb` + root `vX.Y.Z` tag + GitHub release.
8. MCP Registry publish is a manual dispatch: [publish_mcp_registry.yml](https://github.com/Arenukvern/mcp_flutter/blob/main/.github/workflows/publish_mcp_registry.yml) with the release tag (runbook: [mcp_registry_publish_runbook.mdx](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/contributing/mcp_registry_publish_runbook.mdx)).

Before automated publishing can run, each package needs a first manual signed-in publish and pub.dev Admin → Automated publishing enabled with a **per-package tag pattern** (`flutter_mcp_toolkit_<name>-v{{version}}`). No GitHub Actions environment is involved — repository + tag pattern + pubspec version are the authorization (see the dart_changesets engine README's "pub.dev authorization" section for the design and hardening routes). Decision record: [ADR 0022](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/decisions/0022_no_github_environment_in_publish_path.mdx).

Config: [changesets.yaml](https://github.com/Arenukvern/mcp_flutter/blob/main/changesets.yaml); intent files in [.changesets/](https://github.com/Arenukvern/mcp_flutter/blob/main/.changesets/).

**README badge discipline:** the badge row carries the **release train** badge (`dart_changesets.yml` status) and the **release engine: dart_changesets** attribution badge — snippets live in the engine README's "Show your release train (consumer badge)" section. A red train badge is the first visible signal the automation broke (usually the workflow-permission setting or a failed tag dispatch) — fix it before cutting the next release.

## Manual release (fallback)

Use when release-please is unavailable or you must ship from a branch:

1. Move `## [Unreleased]` bullets into `## [X.Y.Z]` (add date), leave empty `## [Unreleased]`.
2. Update `VERSION` to `X.Y.Z`.
3. `make sync-version` to derive all version touchpoints and `.release-please-manifest.json`.
4. `make sync-skills` (required whenever plugin manifests or skills change).
5. `make check-contracts`
6. Commit: `chore: release X.Y.Z`
7. Optional pub.dev preflight: `make publish-pub-dry-run`.
8. Tag: `git tag vX.Y.Z` and push tag (triggers binary and pub.dev workflows).

Build artifacts locally: `make release-artifacts` or `bash tool/release/build_release_artifacts.sh --version X.Y.Z`.
Publish pub.dev packages locally only as a fallback: `make publish-pub`.

## Docs map (single sources of truth)

| Topic                    | Canonical doc                                                                                                                                                    |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| End-user agent install   | [docs/install/clients.mdx](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/install/clients.mdx)                                                         |
| `npx skills` + lockfile  | [clients.mdx](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/install/clients.mdx) § skills; [.skills.json.example](https://github.com/Arenukvern/mcp_flutter/blob/main/.skills.json.example) |
| Contributor / releases   | [docs/contributing/guide.mdx](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/contributing/guide.mdx)                                                    |
| Plugin layout            | [plugin/README.md](https://github.com/Arenukvern/mcp_flutter/blob/main/plugin/README.md)                                                                         |
| Marketplace copy SSOT    | [plugin/assets/marketplace_copy.yaml](https://github.com/Arenukvern/mcp_flutter/blob/main/plugin/assets/marketplace_copy.yaml)                                   |
| Distribution / stores    | [docs/install/clients.mdx](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/install/clients.mdx)                                                         |
| Store submission runbook | [docs/contributing/marketplace_submission_runbook.mdx](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/contributing/marketplace_submission_runbook.mdx) |
| Skill bodies             | `plugin/skills/<id>/SKILL.md` → `make sync-skills`                                                                                                               |

Avoid duplicating install tables in README — link to [docs/index.mdx](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/index.mdx).

## Skills maintenance

- Canonical skills: `plugin/skills/` (repo root `skills/` → symlink for `npx skills`).
- New bundled skill: add `plugin/skills/<id>/SKILL.md`, append `id` to `expectedSkillIds` in [build_skill_assets.dart](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_server_dart/tool/build_skill_assets.dart), run `make sync-skills`.
- Local Cursor copy: `.cursor/skills/<id>/` may symlink to `plugin/skills/<id>/`.
- Platform dogfood skills: `flutter-mcp-toolkit-maintain-web`, `flutter-mcp-toolkit-maintain-macos`, `flutter-mcp-toolkit-dogfood-iterations`.

### HyperFrames promo (flutter_mcp_video repo)

Video skill and projects live in **[flutter_mcp_video](https://github.com/Arenukvern/flutter_mcp_video)** (`skills/hyperframes-video/`, `projects/video-projects/<id>/`). Not bundled in toolkit `make sync-skills`.

When shipping a promo there: edit the video repo; run `bash tool/check_doc_paths.sh` in that repo before merge. Toolkit repo only hosts shared brand assets under `plugin/assets/` (symlink targets for v7-weaver).

## IntentCall consumer maintainer gate

When changing IntentCall consumer integration in `mcp_flutter`:

1. Append `flutter-mcp-toolkit-intentcall-migration` to `expectedSkillIds` in `build_skill_assets.dart` if not already present.
2. `make sync-skills` — commit `skill_assets.g.dart` with skill edits.
3. `bash tool/contracts/check_intentcall_skills_grep.sh` — no legacy call-entry symbol outside migration skill.
4. `cd mcp_server_dart && dart test test/contract/`
5. `flutter-mcp-toolkit migrate agent-entries --check showcase/flutter_test_app/lib` (expect exit 0)
6. Keep canonical IntentCall design links pointed at the IntentCall repository; keep this repo focused on hosted dependency and regression proof.

## Pre-merge checklist

- [ ] `make check-contracts`
- [ ] `make sync-skills` if `plugin/skills/` or `plugin/*-plugin/plugin.json` changed
- [ ] CHANGELOG `[Unreleased]` updated for user-visible changes
- [ ] No secrets in committed configs
