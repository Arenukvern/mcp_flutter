---
'mcp_toolkit': minor
---

Re-`addEntries` for an existing tool name updates the live VM service extension handler via registry indirection (the Dart VM cannot unregister extensions). Document hot reload vs hot restart semantics in the package README.

### Behavior change (debug)

`addEntries` now throws `StateError` instead of silently picking a winner when:

- The same tool `name` is registered under two namespaces:  
  `Duplicate tool name "…" in namespaces "…" and "…".`
- Two registry keys share one VM extension (`methodName` / `serviceExtensionName` collision):  
  `Duplicate VM service extension "…" for registry keys "…" and "…". Give one tool a unique methodName or rename the tool.`

**Migration:** Give one of the tools a unique `methodName`, or rename the tool so keys and VM extension names do not collide.
