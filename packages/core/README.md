# flutter_mcp_toolkit_core

Pure-Dart shared types for [Flutter MCP Toolkit](https://github.com/Arenukvern/mcp_flutter): command envelopes, `CoreResult` / `CoreError`, error codes, connection overrides, and capability models.

No Flutter SDK, `dart_mcp`, or transport dependencies.

## Install

```yaml
dependencies:
  flutter_mcp_toolkit_core: ^0.1.0
```

## Usage

```dart
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

// CoreCommand, CoreResult, CoreErrorCode, parseConnectionOverride, …
```

## Monorepo

This package lives in the [mcp_flutter](https://github.com/Arenukvern/mcp_flutter) monorepo. Server and plugin releases use path dependencies; published consumers use hosted versions on pub.dev.

## Pub.dev publishing checklist

| Requirement | Status |
|-------------|--------|
| `LICENSE` (MIT) | Included |
| `README.md` | This file |
| `CHANGELOG.md` | Included |
| `pubspec.yaml`: `description`, `repository`, `issue_tracker` | Set |
| Hosted dependencies only (no `path:` / `git:`) | Yes |
| `dart pub publish --dry-run` | Run before each release |
| SDK: `>=3.12.0 <4.0.0` | Set in `pubspec.yaml` |
| Public API docs (≥20% for PANA) | Add `///` on exported APIs over time |

See [Dart publishing guide](https://dart.dev/tools/pub/publishing).

## License

MIT — see [LICENSE](LICENSE).
