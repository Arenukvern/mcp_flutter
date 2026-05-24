# flutter_mcp_toolkit_capability_core

Core MCP capability (`fmt`) for [Flutter MCP Toolkit](https://github.com/Arenukvern/mcp_flutter): VM inspection, UI interaction, navigation, logs, diagnostics, and hot-reload coordination.

Server-side Dart only — no Flutter SDK dependency.

## Install

```yaml
dependencies:
  flutter_mcp_toolkit_capability_core: ^0.1.0
  flutter_mcp_toolkit_capability_kernel: ^0.1.0
  flutter_mcp_toolkit_core: ^0.1.0
```

## Usage

```dart
import 'package:flutter_mcp_toolkit_capability_core/flutter_mcp_toolkit_capability_core.dart';

final capability = FmtCapability(/* host services */);
```

## Monorepo development

`pubspec_overrides.yaml` resolves sibling packages from local paths (not published).

## Pub.dev publishing checklist

| Requirement | Status |
|-------------|--------|
| `LICENSE`, `README.md`, `CHANGELOG.md` | Included |
| Hosted sibling deps in `pubspec.yaml` | kernel + core `^0.1.0` |
| Publish **after** kernel and core `0.1.0` on pub.dev | Required |
| `dart pub publish --dry-run` | Run before release |

## License

MIT — see [LICENSE](LICENSE).
