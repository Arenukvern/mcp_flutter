<div align="center">

# MCP Server + Flutter MCP Toolkit

_For AI-Powered Development_

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![smithery badge](https://smithery.ai/badge/@Arenukvern/mcp_flutter)](https://smithery.ai/server/@Arenukvern/mcp_flutter)
[![Pub Version](https://img.shields.io/badge/version-0.1.1-blue)](https://github.com/Arenukvern/mcp_flutter)

</div>

<a href="https://glama.ai/mcp/servers/qnu3f0fa20">
<img width="380" height="200" src="https://glama.ai/mcp/servers/qnu3f0fa20/badge" alt="Flutter Inspector Server MCP server" />
</a>

🔍 Model Context Protocol (MCP) server that connects your Flutter apps with AI coding assistants like Cursor, Claude, Cline, Windsurf, RooCode or any other AI assistant that supports MCP server

<!-- Media -->

![View Screenshots](docs/view_screenshots.gif)

<!-- End of Media -->

## 📖 Documentation

- [Quick Start](QUICK_START.md)
- [Configuration](CONFIGURATION.md)

### Video tutorial how to setup mcp server on macOS (Soon):

- with Cursor:
- with VSCode + Cline:

> [!NOTE]
> There is a new [experimental package in development from Flutter team](https://github.com/dart-lang/ai/tree/main/pkgs/dart_tooling_mcp_server) which exposes Dart tooling development.
>
> Therefore my current focus is
>
> 1. to stabilize and polish tools which are useful in development (so it would be more plug & play, for example: it will return not only the errors, but prompt for AI how to work with that error) [see more in MCP_RPC_DESCRIPTION.md](MCP_RPC_DESCRIPTION.md)
> 2. fine-tune process of MCP server tools creation by making it customizable.
>
> Hope it will be useful for you,
>
> Have a nice day!

v2 released! Now Flutter MCP server works without forwarding server. Please see [Architecture](https://github.com/Arenukvern/mcp_flutter/blob/main/ARCHITECTURE.md) for more details.

## ⚠️ WARNING ⚠️

Dump RPC methods (like `dump_render_tree`), may cause huge amount of tokens usage or overload context. Therefore now they are disabled by default, but can be enabled via environment variable `DUMPS_SUPPORTED=true`.

See more details about environment variables in [.env.example](mcp_server/.env.example).

## 🚀 Getting Started

- Quick Start is available in [QUICK_START.md](QUICK_START.md)
- Configuration options are available in [CONFIGURATION.md](CONFIGURATION.md)

## 🎯 Available tools for AI Agents

### Error Analysis

- `get_app_errors` [Resource|Tool] - Retrieves precise and condensed error information from your Flutter app
  **Usage**:

  - Uses only short description of the error. Should filter duplicate errors, to avoid flooding Agent context window with the same errors.
  - Uses Error Monitor to capture Dart VM errors. Meaning: first, start mcp server, forwarding server, start app, open devtools and extension, and then reload app, to capture errors. All errors will be captured in the DevTools Extension (mcp_toolkit).

  **Tested on**:
  ✅ macOS, ✅ iOS
  **Not tested on**:
  🚧 Android, 🤔 Windows, 🤔 Linux, ❌ Web
  [See issue](https://github.com/Arenukvern/mcp_flutter/issues/23)

### Development Tools

- `hot_reload` [Tool] - Performs hot reload of the Flutter application
  **Tested on**:
  ✅ macOS, ✅ iOS, ✅ Android
  **Not tested on**:
  🤔 Windows, 🤔 Linux, ❌ Web
  [See issue](https://github.com/Arenukvern/mcp_flutter/issues/23)
- `screenshot` [Resource|Tool] - Captures a screenshot of the running application.
  **Configuration**:

  - Enable with `--images` flag or `IMAGES_SUPPORTED=true` environment variable
  - May use compression to optimize image size

  **Tested on**:
  ✅ macOS, ✅ iOS
  **Not tested on**:
  🚧 Android, 🤔 Windows, 🤔 Linux, ❌ Web
  [See issue](https://github.com/Arenukvern/mcp_flutter/issues/23)

All tools default to using port 8181 if no port is specified. You can override this by providing a specific port number.

📚 Please see more in [MCP_RPC_DESCRIPTION](MCP_RPC_DESCRIPTION.md)

## 🔧 Troubleshooting

4. **Connection Issues**

   - Ensure your Flutter app is running in debug mode
   - Verify the port matches in both Flutter app and inspector
   - Check if the port is not being used by another process

5. **AI Tool Not Detecting Inspector**
   - Restart the AI tool after configuration changes
   - Verify the configuration JSON syntax
   - Check the tool's logs for connection errors

The Flutter Inspector is registered with Smithery's registry, making it discoverable and usable by other AI tools through a standardized interface.

### Integration Architecture

```
┌─────────────────┐     ┌───────────────────────┐     ┌─────────────────┐
│                 │     │  Flutter App with     │     │                 │
│  Flutter App    │<--->│  mcp_toolkit (VM Svc.  │<--->│   MCP Server   │
│  (Debug Mode)   │     │  Extensions)          │     │                 │
│                 │     │                       │     │                 │
└─────────────────┘     └───────────────────────┘     └─────────────────┘
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or report issues on the [GitHub repository](https://github.com/Arenukvern/mcp_flutter).

## 📖 Learn More

- [Flutter DevTools Documentation](https://docs.flutter.dev/development/tools/devtools/overview)
- [Dart VM Service Protocol](https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md)
- [Flutter DevTools RPC Constants (I guess and hope they are correct:))](https://github.com/flutter/devtools/tree/87f8016e2610c98c3e2eae8b1c823de068701dfd/packages/devtools_app/lib/src/shared/analytics/constants)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=Arenukvern/mcp_flutter&type=Date)](https://www.star-history.com/#Arenukvern/mcp_flutter&Date)

## 📄 License

[MIT](LICENSE) - Feel free to use in your projects!

---

_Flutter and Dart are trademarks of Google LLC._
