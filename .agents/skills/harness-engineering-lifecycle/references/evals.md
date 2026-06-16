# Evals — harness-engineering-lifecycle

## Should trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| T1 | Generalize a Steward harness across producer consumer repos after local contract exists | Routes to producer/consumer dogfood and dual verification. |

## Should not trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| N1 | Add a first quick-safe action to a single project | Routes to `mcp-harness-repo-maintainer` instead. |

## Held-out

| ID | Prompt | Notes |
|----|--------|-------|
| H1 | Fix one repo's first `steward.yaml` adoption | Should stay local; do not generalize yet. |

## Edit log

| Date | Change | Kept? |
|------|--------|-------|
| 2026-06-05 | Added T1 behavior-critical routing cases for producer/consumer boundary coverage | Yes |
