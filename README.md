[![MseeP.ai Security Assessment Badge](https://mseep.net/pr/arenukvern-mcp-flutter-badge.png)](https://mseep.ai/app/arenukvern-mcp-flutter)

# Flutter Inspector MCP Server for AI-Powered Development

[GitHub Repository](https://github.com/Arenukvern/mcp_flutter)
[![smithery badge](https://smithery.ai/badge/@Arenukvern/mcp_flutter)](https://smithery.ai/server/@Arenukvern/mcp_flutter)

🔍 Model Context Protocol (MCP) server that connects your Flutter apps with AI coding assistants like Cursor, Claude, Cline, Windsurf, RooCode or any other AI assistant that supports MCP server

See small video tutorial how to setup mcp server on macOS with Cursor - https://www.youtube.com/watch?v=NBY2p7XIass

<a href="https://glama.ai/mcp/servers/qnu3f0fa20">
  <img width="380" height="200" src="https://glama.ai/mcp/servers/qnu3f0fa20/badge" alt="Flutter Inspector Server MCP server" />
</a>

> [!NOTE]
> Since there is a new [experimental package in development](https://github.com/dart-lang/ai/tree/main/pkgs/dart_tooling_mcp_server) which exposes Dart tooling development tool actions to clients, maybe in future this project may be not needed that much.
>
> Therefore my current focus is
>
> 1. to stabilize and polish only these tools that will be useful in development (so it would be more plug & play) [see more in MCP_RPC_DESCRIPTION.md](MCP_RPC_DESCRIPTION.md)
> 2. find workaround to not use forwarding server.
>
> Hope it will be useful for you,
>
> Have a nice day!

Currently Flutter works with MCP server via forwarding server. Please see [Architecture](https://github.com/Arenukvern/mcp_flutter/blob/main/ARCHITECTURE.md) for more details.

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
  - Uses Error Monitor to capture Dart VM errors. Meaning: first, start mcp server, forwarding server, start app, open devtools and extension, and then reload app, to capture errors. All errors will be captured in the DevTools Extension (mcp_bridge).

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

`get_app_errors`- Since errors are captured in DevTools Extension, you need to make sure that, you have restarted or reloaded Flutter app after starting MCP server, forwarding server and DevTools mcp_bridge extension.

Also make sure you:

1. Verify that forwarding server is running.
2. Opened Devtools in Browser.
3. Have added MCP extension to your Flutter app dev dependencies and enabled it in Devtools.

4. **Connection Issues**

   - Ensure your Flutter app is running in debug mode
   - Verify the port matches in both Flutter app and inspector
   - Check if the port is not being used by another process

5. **AI Tool Not Detecting Inspector**
   - Restart the AI tool after configuration changes
   - Verify the configuration JSON syntax
   - Check the tool's logs for connection errors

## 🚧 Smithery Integration 🚧 (work in progress)

The Flutter Inspector is registered with Smithery's registry, making it discoverable and usable by other AI tools through a standardized interface.

### Integration Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌──────────────┐     ┌─────────────────┐     ┌─────────────┐
│                 │     │              │     │              │     │                 │     │             │
│  Flutter App    │<--->│  DevTools    │<--->│  Forwarding  │<--->│   MCP Server   │<--->│  Smithery   │
│  (Debug Mode)   │     │  Extension   │     │  Server      │     │   (Registered) │     │  Registry   │
│                 │     │              │     │              │     │                 │     │             │
└─────────────────┘     └──────────────┘     └──────────────┘     └─────────────────┘     └─────────────┘
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or report issues on the [GitHub repository](https://github.com/Arenukvern/mcp_flutter).

## 📖 Learn More

- [Flutter DevTools Documentation](https://docs.flutter.dev/development/tools/devtools/overview)
- [Dart VM Service Protocol](https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md)
- [Flutter DevTools RPC Constants (I guess and hope they are correct:))](https://github.com/flutter/devtools/tree/87f8016e2610c98c3e2eae8b1c823de068701dfd/packages/devtools_app/lib/src/shared/analytics/constants)

## 📄 License

MIT - Feel free to use in your projects!

---

_Flutter and Dart are trademarks of Google LLC._
