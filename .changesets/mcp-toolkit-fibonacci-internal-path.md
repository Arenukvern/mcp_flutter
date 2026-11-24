---
'mcp_toolkit': patch
---

Stop exporting the Fibonacci demo helper from the public `mcp_toolkit.dart` barrel. The single copy lives at `lib/examples/fibonacci.dart` (demo-only, no API stability guarantees); import `package:mcp_toolkit/examples/fibonacci.dart` from the package example app or showcase integration wiring — not a supported semver surface.