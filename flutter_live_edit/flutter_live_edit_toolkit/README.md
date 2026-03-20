# flutter_live_edit_toolkit

In-app Live Edit runtime: overlay host, `LiveEditScope`, MCP bridge registration, commands.

## Start here

Import the **facade** for a small, opinionated surface:

```dart
import 'package:flutter_live_edit_toolkit/live_edit_facade.dart';
```

That exposes `bootstrapFlutterLiveEditApp`, `LiveEditScope`, `FlutterLiveEditHost`, `LiveEditRuntime`, and `getFlutterLiveEditEntries`.

For orchestrator, theme, selectors, and the full command list, import the barrel:

```dart
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
```

## Contracts

- **User story & glossary:** `../USER_STORY.md`, `../CONTRACT.md`
- **Toolkit ↔ agent dependency:** `../BOUNDARIES.md`
