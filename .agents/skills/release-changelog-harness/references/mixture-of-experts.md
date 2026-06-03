# Mixture of experts — release changelog harness

Extended critique for the idea: *“Adopt JS-style Changesets culture so releases are understandable.”*

## The idea (strengths)

1. **Intent before version** — Changesets force a sentence of *why* before merge; version math is secondary.
2. **Monorepo-safe** — Independent package bumps without one global “bump everything” commit.
3. **Reviewable in PR** — Reviewers see `.changeset/*.md` like code; not a surprise CHANGELOG on release day.
4. **Agent-friendly** — Small markdown files with frontmatter are easy to generate and validate in CI.
5. **Cultural proof** — Large OSS JS orgs normalized this; newcomers already know the ritual.

## The idea (risks)

1. **Ecosystem imperialism** — Dart pub, Cargo, and Flutter plugin trains have mature native flows; Changesets is npm-centric.
2. **Skill bloat** — A skill that embeds full Changesets + release-please + Melos configs becomes a domain tutorial (violates Skill Steward North Star).
3. **Double automation** — Repos that already use release-please or custom release trains break if you add Changesets without an ADR.
4. **Empty ritual** — Teams add `.changeset` with “misc” bullets; legibility does not improve.
5. **Agent-only releases** — Letting agents write CHANGELOG at tag time without PR artifacts recreates the opacity you escaped.

## Expert resolutions (synthesis)

| Tension | Resolution |
|---------|------------|
| “We love Changesets” vs “We’re not JS” | **Contract first**, generator second. |
| Human prose vs agent structure | Require **structured contributor files**; allow agents to draft them in PRs. |
| One repo vs `~/mcp` siblings | Same **contract**; document per-repo command in each DX_FAQ. |
| Simple vs complete | Start with **CI gate + DX_FAQ block**; add Changesets when workspace count > 1 or release pain is real. |

## When Changesets is the wrong default

- Primary artifact is **not** npm (Rust workspace, Dart pub, container image only).
- **Single** package with conventional commits already drive release-please cleanly.
- Release is **binary + manifest** driven (plugin.json, skill_assets) — extend existing sync scripts; don’t add npm versioning on top.

## When Changesets is the right default

- `pnpm-workspace` / npm workspaces with **multiple publishable packages**.
- Agents and humans both ship; you need **file-shaped** release intent in git.
- You want **patch/minor/major** decisions explicit per package in review.

## Recommended upgrade to the original idea

Name the outcome, not the tool:

**Before:** “Use Changesets like the JS community.”

**After:** “Ship a **release legibility harness**: structured notes in git, ecosystem-native versioning tool, CI-enforced, DX_FAQ-documented—Changesets when the repo is a JS workspace monorepo.”

That keeps the cultural win without colonizing non-JS harness repos.
