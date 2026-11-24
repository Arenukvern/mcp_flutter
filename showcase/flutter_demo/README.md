# flutter_demo

Minimal **instrumented** Flutter app for `ToolkitDriver` and
[`showcase/drivers/bin/drive_flutter.dart`](../drivers/bin/drive_flutter.dart).

Counter, name field, and `/profile` route — each control has a plain label or
semantics identifier so harness and MCP tools can resolve widgets from a
semantic snapshot.

**Not** the public product showcase — that is
[`flutter_test_app`](../flutter_test_app/README.md) (ADR-0025).

```bash
dart run showcase/drivers/bin/drive_flutter.dart
dart run showcase/drivers/bin/drive_flutter.dart --device chrome
```