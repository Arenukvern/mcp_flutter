# Pending release intents

One markdown file per release intent, consumed by the assembler when the
version PR is built:

```markdown
---
'oka_core': patch
---

What changed, as changelog prose.
```

Create one with `dart run dart_changesets add` (or write the file by hand).
Consumed files are deleted when the version PR is applied.
