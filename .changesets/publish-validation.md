---
'mcp_toolkit': patch
'flutter_mcp_toolkit_server': patch
---

Make both packages pass `pub publish` validation again, which had blocked their release legs: `mcp_toolkit` clears the analyzer findings in `lib/` (unused locals in the wait-predicate service, redundant `!`, const and null-aware cleanups, directive order, relative import in the Fibonacci example); `flutter_mcp_toolkit_server` declares `repository` and moves its maintainer docs to `doc/`.
