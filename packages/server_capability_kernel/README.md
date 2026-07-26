# flutter_mcp_toolkit_capability_kernel

[![pub package](https://img.shields.io/pub/v/flutter_mcp_toolkit_capability_kernel.svg?include_prereleases)](https://pub.dev/packages/flutter_mcp_toolkit_capability_kernel)
[![pub points](https://img.shields.io/pub/points/flutter_mcp_toolkit_capability_kernel.svg)](https://pub.dev/packages/flutter_mcp_toolkit_capability_kernel/score)

Capability kernel for [Flutter MCP Toolkit](https://github.com/Arenukvern/mcp_flutter): `Capability`, `CapabilityContext`, `HostService`, tool/resource registration, and `<capabilityId>_` name prefixing.

Pure Dart — no Flutter SDK or transport.

## Install

```yaml
dependencies:
  flutter_mcp_toolkit_capability_kernel: ^4.0.0-dev.7
  flutter_mcp_toolkit_core: ^4.0.0-dev.7
```

## Usage

```dart
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';

// Implement Capability, register tools via CapabilityContext.
```

## Monorepo development

Use `pubspec_overrides.yaml` in this directory (not published) to resolve `flutter_mcp_toolkit_core` from `../flutter_mcp_toolkit_core`.

## Pub.dev publishing checklist

| Requirement | Status |
|-------------|--------|
| `LICENSE`, `README.md`, `CHANGELOG.md` | Included |
| Hosted deps only in `pubspec.yaml` | `flutter_mcp_toolkit_core: ^4.0.0-dev.7` |
| Publish **after** `flutter_mcp_toolkit_core` `4.0.0-dev.7` is on pub.dev | Required for consumers |
| `dart pub publish --dry-run` | Run before release |

## License

MIT — see [LICENSE](LICENSE).
