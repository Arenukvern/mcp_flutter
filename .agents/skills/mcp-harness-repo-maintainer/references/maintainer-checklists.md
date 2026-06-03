# Maintainer checklists (reference)

Copy the section for your archetype before a release or large PR.

## Archetype A — Product MCP

- [ ] Verify all project versions and manifests match (`VERSION` == expected server version == manifest files)
- [ ] Run skill/manifest sync script if manifests or skills changed
- [ ] Ensure contract check tasks are green
- [ ] CHANGELOG `## [Unreleased]` updated
- [ ] Update agent listing configs/YAML files if listing text changed
- [ ] Confirm all synchronized assets/generated files are committed or automatically generated in release PR
- [ ] Confirm server binaries are built and attached on tag/release (if relevant)
- [ ] Optional: validate runtime environment & execute dogfooding loop

## Archetype B — Platform Libs

- [ ] Run package static analysis and unit tests on all packages/modules
- [ ] Execute dry-run publish commands before publishing
- [ ] Ensure public API and schema tests are updated
- [ ] Verify integration checks in the consuming Product MCP are green on integration PR
- [ ] Ensure publishing documentation matches the actual publish order

## Archetype C — CLI Harness

- [ ] Local path overrides (e.g., workspaces, overrides) point at sibling product MCP (for local development)
- [ ] Run unit and integration tests
- [ ] Run test harness fixture checks (e.g., validate and run fixtures)
- [ ] Verify registry config files are correct
- [ ] Check sibling/related repo references are accurate in docs
- [ ] Verify skills/checklists match harness workflows

## Archetype D — Visual Sidecar

- [ ] Run unit tests
- [ ] Run profile validation tools against comparison profiles
- [ ] Ensure no runtime dependencies on product MCP or runtime VMs (maintain sidecar isolation)
- [ ] Run export/registry scripts if profiles are added
- [ ] Document consumers (harness comparison steps, dogfood golden path)

## Archetype E — Meta Steward (e.g., skill_steward)

- [ ] Run static analysis and lints on linter/validator CLI
- [ ] Run validator CLI against meta-skills
- [ ] Validate documentation / site checker if documentation touched
- [ ] Sync skills registries and README tables
- [ ] Ensure no domain/product MCP or product domain skills are added
- [ ] **No binary release train** — skills via `npx skills` only (see ADR 0010)
- [ ] Verify stale planning/plan files are removed (plan hygiene)
- [ ] Verify IDE hooks / configuration files are valid

## Archetype F — Security (any remote MCP release)

- [ ] Tool schemas reviewed (permissions, PII)
- [ ] No secrets in repo; env var docs only
- [ ] Auth model documented (stdio env vs HTTP OAuth)
- [ ] Additive schema changes only unless major version bump
- [ ] Gateway/audit path for production fleet
