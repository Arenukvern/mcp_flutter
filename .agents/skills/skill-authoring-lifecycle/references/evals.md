# Evals — skill-authoring-lifecycle

## Should trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| T1 | Add skill `release-changelog-harness` | Valid layout, registry, validate passes |

## Should not trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| N1 | Deploy K8s with Terraform | Dormant |

## Held-out

| ID | Prompt | Notes |
|----|--------|-------|
| H1 | New skill with invalid `name` | Skill guides fix before merge |

## Edit log

| Date | Change | Kept? |
|------|--------|-------|
