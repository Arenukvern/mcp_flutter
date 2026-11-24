---
'mcp_toolkit': patch
---

Stop exporting the Fibonacci integration helper from the public `mcp_toolkit.dart` barrel. Apps that need `buildCalculateFibonacciTool()` should import `package:mcp_toolkit/src/examples/example_fibonacci.dart` (showcase / example apps only; not part of the supported pub API surface).