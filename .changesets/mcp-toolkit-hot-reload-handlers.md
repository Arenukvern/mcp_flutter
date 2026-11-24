---
'mcp_toolkit': patch
---

Re-`addEntries` for an existing tool name updates the live VM service extension handler via registry indirection (the Dart VM cannot unregister extensions). Document hot reload vs hot restart semantics in the package README.