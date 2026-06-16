# Evals — plugin-marketplace-setup

## Should trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| T1 | Design a private plugin marketplace for Codex and Cursor team installs | Routes to marketplace/channel matrix and install docs. |

## Should not trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| N1 | Create a repo ADR about plan hygiene | Routes to `repository-governance-lifecycle`. |

## Held-out

| ID | Prompt | Notes |
|----|--------|-------|
| H1 | Install one public skill with `npx skills` | Should not trigger broad marketplace design. |

## Edit log

| Date | Change | Kept? |
|------|--------|-------|
| 2026-06-05 | Added T1 behavior-critical routing cases for plugin/marketplace boundary coverage | Yes |
