<div align="center">

# MCP Server + Flutter MCP Toolkit

_For AI-Powered Development_

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![smithery badge](https://smithery.ai/badge/@Arenukvern/mcp_flutter)](https://smithery.ai/server/@Arenukvern/mcp_flutter)
[![Verified on MseeP](https://mseep.ai/badge.svg)](https://mseep.ai/app/03aa0f2d-4ef7-40ae-93de-c7b87e0ac32d)
[![All Contributors](https://img.shields.io/github/all-contributors/Arenukvern/mcp_flutter?color=ee8449&style=flat-square)](https://github.com/Arenukvern/mcp_flutter#contributors-)

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

> [!NOTE]
> There is official [MCP Server for Flutter from Flutter team](https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp_server) which exposes Dart tooling.
>
> The **main goal of this project** is to bring power of MCP server tools by creating them in Flutter app, using **dynamic MCP tools registration** . See how it works in [short YouTube video](https://www.youtube.com/watch?v=Qog3x2VcO98). See [Quick Start](QUICK_START.md) for more details. See [original motivation](https://github.com/Arenukvern/mcp_flutter/blob/main/CHANGELOG.md#210) behind the idea.
>
> Also, secondary goal is to stabilize and polish tools which are useful in development (so it would be specifically targeted for AI Assistants, for example: it will return not only the errors, but prompt for AI how to work with that error) [see more in MCP_RPC_DESCRIPTION.md](MCP_RPC_DESCRIPTION.md)
>
> Please share your feedback, ideas and suggestions in issues!
>
> Hope it will be useful for you,
>
> Have a nice day!

## 🎉 v2.3.0 released! 🎉

- feature: Added support for saving captured screenshots as files instead of returning them as base64 data, with automatic cleanup of old screenshots. Use (`--save-images`) flag to enable it.

- fix: Fixed various issues with dynamic registry, made logs level error by default.

- perf: v0.2.3 - added more checks for [MCPCallEntry.resourceUri] for MCPToolkit package (MCPToolkit updated to v0.2.3)
- disabled resources support by default for RooCode and Cline setups (for unknown reason it doesn't work)
- added section for RooCode in QUICK_START.md
- Huge thank you to [cosystudio](https://github.com/cosystudio) for raising, researching and (describing issues)[https://github.com/Arenukvern/mcp_flutter/issues/53] with RooCode MCP server.

**Major Changes in v2.2.0:**

- **Dart-based MCP Server now is the main server**: Typescript server removed, and `mcp_server_dart` is the main server.
- **Dynamic Tools Registration**: Flutter apps can now register custom tools at the MCP server. See how it works in [short YouTube video](https://www.youtube.com/watch?v=Qog3x2VcO98). See [Dynamic Tools Registration Docs](https://github.com/Arenukvern/mcp_flutter/blob/main/QUICK_START.md#dynamic-tools-registration) for more details.

See more details in [CHANGELOG.md](CHANGELOG.md).

## ⚠️ WARNING

Dump RPC methods (like `dump_render_tree`), may cause huge amount of tokens usage or overload context. Therefore now they are disabled by default, but can be enabled via `--dumps` flag.

See more details about command line options in [mcp_server_dart README](mcp_server_dart/README.md).

## 🚀 Getting Started

- (Experimental) You can try to install MCP server and configure it using your AI Agent. Use the following prompt: `Please install MCP server using this link: https://github.com/Arenukvern/mcp_flutter/blob/main/llm_install.md`

- with Cursor: https://www.youtube.com/watch?v=pyDHaI81uts
- with VSCode + Cline: use prompt `Please install MCP server using this link: https://github.com/Arenukvern/mcp_flutter/blob/main/llm_install.md`

- Quick Start is available in [QUICK_START.md](QUICK_START.md)
- Configuration options are available in [CONFIGURATION.md](CONFIGURATION.md)

## 🎯 AI Agent Tools

### Core Flutter Tools

- `get_app_errors` [Resource|Tool] - Retrieves precise and condensed error information from your Flutter app
  **Usage**:

  - Uses only short description of the error. Should filter duplicate errors, to avoid flooding Agent context window with the same errors.
  - Uses Error Monitor to capture Dart VM errors. All errors captured in Flutter app, and then available by request from MCP server.

  **Tested on**:
  ✅ macOS, ✅ iOS
  **Not tested on**:
  🚧 Android, 🤔 Windows, 🤔 Linux, ❌ Web
  [See issue](https://github.com/Arenukvern/mcp_flutter/issues/23)

- `view_screenshot` [Resource|Tool] - Captures screenshots of the running application.
  **Configuration**:

  - Enable with `--images` flag
  - Will use PNG compression to optimize image size.

- `get_view_details` [Resource|Tool] - size of screen, pixel ratio. May unlock ability for an Agent to use widget selection. Will return details about each view in the app.

### Dynamic Tools Registration 🆕

**Dynamic Registration Features:**

Flutter apps can now register custom tools and resources at runtime. See how it works in [short YouTube video](https://www.youtube.com/watch?v=Qog3x2VcO98). See [Dynamic Tools Registration Docs](#dynamic-tools-registration-🆕) for more details.

All tools default to using port 8181 if no port is specified. You can override this by providing a specific port number.

📚 Please see more in [MCP_RPC_DESCRIPTION](MCP_RPC_DESCRIPTION.md)

## 🔒 Security

Generally, since you use MCP server to connect to Flutter app in Debug Mode, it should be safe to use. However, I still recommend to review how it works in [ARCHITECTURE.md](ARCHITECTURE.md), how it can be modified to improve security if needed.

This MCP server is verified by [MseeP.ai](https://mseep.ai).

[![MseeP.ai Security Assessment Badge](https://mseep.net/pr/arenukvern-mcp-flutter-badge.png)](https://mseep.ai/app/arenukvern-mcp-flutter)

## 🔧 Troubleshooting

1. **Connection Issues**

   - Ensure your Flutter app is running in debug mode
   - Verify the port matches in both Flutter app and MCP server
   - Check if the port is not being used by another process

2. **AI Tool Not Detecting Inspector**

   - Restart the AI tool after configuration changes
   - Verify the configuration JSON syntax
   - Check the tool's logs for connection errors

3. **Dynamic Tools Not Appearing**
   - Ensure `mcp_toolkit` package is properly initialized in your Flutter app
   - Check that tools are registered using `MCPToolkitBinding.instance.addEntries()`
   - Use `listClientToolsAndResources` to verify registration
   - Hot reload your Flutter app after adding new tools

The Flutter MCP Server is registered with Smithery's registry, making it discoverable and usable by other AI tools through a standardized interface.

### Integration Architecture

```
┌─────────────────┐     ┌───────────────────────┐     ┌─────────────────┐
│                 │     │  Flutter App with     │     │                 │
│  Flutter App    │<--->│  mcp_toolkit (VM Svc.  │<--->│ MCP Server Dart │
│  (Debug Mode)   │     │  Extensions + Dynamic │     │                 │
│                 │     │  Tool Registration)   │     │                 │
└─────────────────┘     └───────────────────────┘     └─────────────────┘
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or report issues on the [GitHub repository](https://github.com/Arenukvern/mcp_flutter).

## ✨ Contributors

Huge thanks to all contributors for making this project better!

<!-- https://allcontributors.org/docs/en/bot/usage -->

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://calclavia.com"><img src="https://avatars.githubusercontent.com/u/1828968?v=4?s=100" width="100px;" alt="Henry Mao"/><br /><sub><b>Henry Mao</b></sub></a><br /><a href="#infra-calclavia" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/marwenbk"><img src="https://avatars.githubusercontent.com/u/18284646?v=4?s=100" width="100px;" alt="Marwen"/><br /><sub><b>Marwen</b></sub></a><br /><a href="#doc-marwenbk" title="Documentation">📖</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://eastagile.com"><img src="https://avatars.githubusercontent.com/u/2829939?v=4?s=100" width="100px;" alt="Lawrence Sinclair"/><br /><sub><b>Lawrence Sinclair</b></sub></a><br /><a href="#doc-lwsinclair" title="Documentation">📖</a> <a href="#security-lwsinclair" title="Security">🛡️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://glama.ai"><img src="https://avatars.githubusercontent.com/u/108313943?v=4?s=100" width="100px;" alt="Frank Fiegel"/><br /><sub><b>Frank Fiegel</b></sub></a><br /><a href="#infra-punkpeye" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Harishwarrior"><img src="https://avatars.githubusercontent.com/u/38380040?v=4?s=100" width="100px;" alt="Harish Anbalagan"/><br /><sub><b>Harish Anbalagan</b></sub></a><br /><a href="#userTesting-Harishwarrior" title="User Testing">📓</a> <a href="#bug-Harishwarrior" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/torbenkeller"><img src="https://avatars.githubusercontent.com/u/33001558?v=4?s=100" width="100px;" alt="Torben Keller"/><br /><sub><b>Torben Keller</b></sub></a><br /><a href="#userTesting-torbenkeller" title="User Testing">📓</a> <a href="#bug-torbenkeller" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/rednikisfun"><img src="https://avatars.githubusercontent.com/u/53967674?v=4?s=100" width="100px;" alt="Isfun"/><br /><sub><b>Isfun</b></sub></a><br /><a href="#userTesting-rednikisfun" title="User Testing">📓</a> <a href="#bug-rednikisfun" title="Bug reports">🐛</a> <a href="#research-rednikisfun" title="Research">🔬</a> <a href="#code-rednikisfun" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/cosystudio"><img src="https://avatars.githubusercontent.com/u/149987661?v=4?s=100" width="100px;" alt="Cosy Studio"/><br /><sub><b>Cosy Studio</b></sub></a><br /><a href="#userTesting-cosystudio" title="User Testing">📓</a> <a href="#bug-cosystudio" title="Bug reports">🐛</a> <a href="#research-cosystudio" title="Research">🔬</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/lukemmtt"><img src="https://avatars.githubusercontent.com/u/1598289?v=4?s=100" width="100px;" alt="Luke Memet"/><br /><sub><b>Luke Memet</b></sub></a><br /><a href="#userTesting-lukemmtt" title="User Testing">📓</a> <a href="#research-lukemmtt" title="Research">🔬</a> <a href="#maintenance-lukemmtt" title="Maintenance">🚧</a> <a href="#tutorial-lukemmtt" title="Tutorials">✅</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

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
