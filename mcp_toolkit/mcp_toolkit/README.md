# MCP Toolkit for Flutter

[![Pub Version](https://img.shields.io/badge/version-0.1.1-blue)](https://github.com/Arenukvern/mcp_flutter/tree/main/mcp_toolkit/mcp_toolkit)

> [!NOTE]
> This is not official package - it's a personal project.
>
> For official package - please see [ai repository](https://github.com/dart-lang/ai/tree/main/pkgs/dart_tooling_mcp_server)

This package is a core component of the [mcp_flutter](https://github.com/Arenukvern/mcp_flutter) project. It acts as the "client-side" library within your Flutter application, enabling the Model Context Protocol (MCP) `MCP Server` to perform Flutter-specific operations like retrieving application errors, capturing screenshots, and getting view details.

> [!NOTE]
> Please notice:
>
> - The architecture of package may change significantly.

## Data Transparency

This package is designed to be transparent and easy to understand. It is built on top of the Dart VM Service Protocol, which is a public protocol for interacting with the Dart VM.

To make it simple and customizable - it divided into groups of methods which acts as method handlers.

For example, to add Flutter tools, you can use `initializeFlutterToolkit()` method like one below.

All methods are available only in debug mode and wrapped in assert statements.

```dart
MCPToolkitBinding.instance
  // Initializes the Toolkit
  ..initialize()
  // Adds Flutter related methods to the MCP server
  ..initializeFlutterToolkit();
```

## Features

- **VM Service Extensions**: Registers a set of custom VM service extensions (e.g., `ext.mcp.toolkit.app_errors`, `ext.mcp.toolkit.view_screenshots`, `ext.mcp.toolkit.view_details`).
- **Error Reporting**: Captures and makes available runtime errors from the Flutter application.
- **Screenshot Capability**: Allows external tools to request screenshots of the application's views.
- **Application Details**: Provides a mechanism to fetch basic details about the application's views.

## Integration

1.  **Add as a Dependency**:
    Add `mcp_toolkit` to your Flutter project's `pubspec.yaml` file.

    If you have the `mcp_flutter` repository cloned locally, you can use a path dependency:

    ```yaml
    dev_dependencies:
      # ... other dev_dependencies
      mcp_toolkit: ^0.1.1
    ```

    Then, run `flutter pub get` in your Flutter project's directory.

2.  **Initialize in Your App**:
    In your Flutter application's `main.dart` file (or equivalent entry point), initialize the bridge binding:

    ```dart
    import 'package:flutter/material.dart';
    import 'package:mcp_toolkit/mcp_toolkit.dart'; // Import the package
    import 'dart:async';

    Future<void> main() async {
      runZonedGuarded(
        () async {
          WidgetsFlutterBinding.ensureInitialized();
          MCPToolkitBinding.instance
            ..initialize() // Initializes the Toolkit
            ..initializeFlutterToolkit(); // Adds Flutter related methods to the MCP server
          runApp(const MyApp());
        },
        (error, stack) {
          // Optionally, you can also use the bridge's error handling for zone errors
          MCPToolkitBinding.instance.handleZoneError(error, stack);
        },
      );
    }

    // ... rest of your app code
    ```

## Role in `mcp_flutter`

For the full setup and more details on the `MCP Server` and AI tool integration, please refer to the main [QUICK_START.md](https://github.com/Arenukvern/mcp_flutter/blob/main/QUICK_START.md) in the root of the `mcp_flutter` repository.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or report issues on the [GitHub repository](https://github.com/Arenukvern/mcp_flutter).

## 📖 Learn More

- [Flutter DevTools Documentation](https://docs.flutter.dev/development/tools/devtools/overview)
- [Dart VM Service Protocol](https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md)

## 📄 License

[MIT](LICENSE) - Feel free to use in your projects!

---

_Flutter and Dart are trademarks of Google LLC._
