# Evals — repository-governance-lifecycle

## Should trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| T1 | Write an ADR and update DESIGN_FAQ for a repository governance architecture change | Routes to the full decide → document → cleanup loop. |
| T2 | This proof note mixes an ADR decision, stale benchmark output, a reusable template, and a completed plan. Decide what becomes evidence, ADR, FAQ, check, or deletion. | Routes to governance cleanup and distinguishes ADR, FAQ, evidence artifact, check/tool, and delete/remove dispositions. |
| T3 | We may need to make repair-first the new center of Skill Steward, or maybe create a sub-North Star for one product repo. | Classifies `north_star_impact`, distinguishes mechanism from mission, and requires ADR plus North Star diff for `amends` or `conflicts`. |

## Should not trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| N1 | Brainstorm three logo directions for a product launch | Dormant; route to creative/product design work instead. |
| N2 | Fix a formatter failure and rerun the repo's native validation gate without changing docs, claims, policy, or architecture. | Dormant; routine repair should keep the original goal and native gate unless it changes structure, claims, policy, or docs-lattice truth. |

## Held-out

| ID | Prompt | Notes |
|----|--------|-------|
| H1 | Update a code comment only | Should not require ADR/FAQ unless it changes standing behavior. |

## Edit log

| Date | Change | Kept? |
|------|--------|-------|
| 2026-06-05 | Added T1 behavior-critical routing cases for governance boundary coverage | Yes |
| 2026-06-12 | Added evidence routing coverage for ADR 0023 claim-proof records | Yes |
| 2026-06-13 | Added North Star impact routing so mission changes cannot drift silently | Yes |
