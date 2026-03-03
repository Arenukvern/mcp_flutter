## 2.6.0

BREAKING CHANGES:

- Dart SDK updated to 3.10.0 with all dependencies updated to the latest versions

- now VM service auto-reconnect when Flutter app restarts. Huge thank you to [@jkitching](https://github.com/jkitching) for PR! https://github.com/Arenukvern/mcp_flutter/pull/73
- dockerfile for MCP Server - not tested.
  Huge thank you to [@arslanmit](https://github.com/arslanmit) for PR with Dockerfile! https://github.com/Arenukvern/mcp_flutter/pull/64

## 2.5.0

- new tool: `hot_restart_flutter` to perform VM Service Hot Restart from MCP.
- VM service integration method `hotRestart()` with namespaced service discovery fallback.

  Huge thank you to [CommentakMedia](https://github.com/CommentakMedia) for PR with Hot Restart tool and docs! https://github.com/Arenukvern/mcp_flutter/pull/67

## 2.4.0

- mcp_toolkit: ^0.3.0 with breaking changes, see [mcp_toolkit/mcp_toolkit/CHANGELOG.md](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_toolkit/mcp_toolkit/CHANGELOG.md)

## 2.3.1

- added new examples for MCPToolkit package dynamic tools usage see [flutter_test_app/lib/main.dart](https://github.com/Arenukvern/mcp_flutter/tree/main/flutter_test_app/lib)
- thanks for [@marwenbk](https://github.com/marwenbk) for asking [issue](https://github.com/Arenukvern/mcp_flutter/issues/56).

## 2.3.0

- perf: added more checks for [MCPCallEntry.resourceUri] for MCPToolkit package (MCPToolkit updated to v0.2.3)

## mcp_server_dart

- feat: Added support for saving captured screenshots as files instead of returning them as base64 data, with automatic cleanup of old screenshots. Use (`--save-images`) flag to enable it.

- fix: Fixed various issues with dynamic registry, made logs level error by default.

- added section for RooCode in QUICK_START.md
- disabled resources support by default for RooCode and Cline setups (for unknown reason it doesn't work)

- Huge thank you to [cosystudio](https://github.com/cosystudio) for raising, researching and (describing issues)[https://github.com/Arenukvern/mcp_flutter/issues/53] with RooCode MCP server.

## 2.2.2

- Added `--await-dnd` flag to wait until DND connection is established. By default `--no-await-dnd` will be applied.
  There will be 5 seconds timeout for DND connection and then server will start without DND connection.

  This is workaround for MCP Clients which don't support tools updates.
  Important: some clients doesn't support it. Use with caution. (disable for Windsurf, works with Cursor)

Thank you [@rednikisfun](https://github.com/rednikisfun) for [raising issue for Windsurf](https://github.com/Arenukvern/mcp_flutter/issues/51).

## 2.2.1

- Added badge to install Flutter Inspector to Cursor in README.md
- Restored License file

## 2.2.0

### 🎉 Dart Server + Dynamic Tools Registration

### 🔄 BREAKING CHANGES.

- **Server Migration**: The main server is now **`mcp_server_dart`** (Dart-based), replacing the previous TypeScript server (`mcp_server`)
- **Configuration Changes**: Updated command-line arguments and removed environment variables
- **Package Version**: Updated `mcp_toolkit` to `^0.2.0`

### ✨ New Features

1. 🆕 Dynamic Tools Registration
   Flutter apps can now register custom tools at runtime.
   See [video](https://www.youtube.com/watch?v=Qog3x2VcO98) of how it works and how to use it.

2. MCP Tools for Dynamic Registry (part of Dynamic Tools Registration)

- `listClientToolsAndResources` - Discover all dynamically registered tools and resources if they are not listed in the AI Assistant (Cursor, Cline, Copilot, Roo Code etc..)
- `runClientTool` - Execute custom tools registered by Flutter applications
- `runClientResource` - Read custom resources registered by Flutter applications
- `getRegistryStats` - Get statistics about the dynamic registry (debug mode only)

### 📦 Migration Guide

1. **Update AI Assistant Configuration**:

   ```json
   {
     "mcpServers": {
       "flutter-inspector": {
         "command": "/path/to/mcp_flutter/mcp_server_dart/build/flutter_inspector_mcp",
         "args": [
           "--dart-vm-host=localhost",
           "--dart-vm-port=8181",
           "--resources",
           "--images",
           "--dynamics"
         ],
         "env": {}
       }
     }
   }
   ```

2. **Update Flutter App Dependencies**:
   ```yaml
   dependencies:
     mcp_toolkit: ^0.2.0
   ```

#### For New Users

Follow the updated [Quick Start Guide](QUICK_START.md) for complete setup instructions.

### 🔧 Technical Changes

1. Command Line Interface

- Instead of environment variables, now you can use command-line flags: `--resources`, `--no-resources`, `--images`, `--dumps`, `--dynamics`
- Improved logging with `--log-level` option

2. MCPToolkit API Updates

- New `addEntries()` method to register tools and resources from Flutter app.
- New `MCPCallEntry.tool()` and `MCPCallEntry.resource()` constructors
- Improved error handling with `MCPCallResult`

### 🐛 Bug Fixes

- Fixed connection stability issues
- Improved error handling for VM service disconnections
- Enhanced port scanning reliability
- Better resource cleanup on app restart

### 🙏 Acknowledgments

Special thanks to the community for feedback and testing, and to the Flutter team for the new Dart MCP Server which made Dart MCP Server possible.

---

## Code Rabbit Poem :)

> In the warren of code, new features appear,
> Dynamic tools hop in—now discovery is clear!
> Registries and managers with event-driven flair,
> Flutter and MCP, a seamless new pair.
> With docs and examples, the future looks bright—
> This bunny approves: the registry's just right!
> 🐇✨

## 2.1.0

This release adds experimental Dart MCP Server.
In future I want to replace Typescript server with Dart one.

The reason is simple: Dart has more tooling for Flutter, and it's easier to develop with it.

The reason why I didn't do it earlier - because I started earlier and at the start there was no Dart MCP Server at all, so only when I already developed first version (with autogenerated tools based on Dart VM methods), I asked question on Flutter Discord server and got reply that there is [MCP server fo Dart tooling in development](https://discord.com/channels/608014603317936148/1159561514072690739/1362482189131841718) which sounds so amazing, so at the moment I thought that I don't need to do it myself and stop the project completely.

Then I figured out, that's it was fun time to develop it, and I would happy to try to complete at least one version.

At the same time I've tried Dart MCP Server and it was not working with Cline at all, so I decided to keep the project alive and try to fine tune it instead, while Dart MCP Server was in development.

Now Dart MCP Server mostly works, and I'm happy to migrate to it. However, in the same time, I found new idea of how MCP Server can be used - and it's not only using Dart VM methods, but just other way of thinking of MCP servers.

The current way to write MCP server tools and resources is to have to write server and all the code is on the server side.

However, I found, that it's not ideal, because if you need to secure what information is sent to the server, or just add new tools / resources for specific project it is not great way to do it.

So after experimenting with some ideas (the most of work is on branch feat/mcp-registry-try3), first:

1. Removed extension and moved all logic for tools and resources to the client. (it's released already as Dart MCPToolkit package)
2. Added ability to register new tools and resources on server from client side. (WIP).

Hopefully, the idea will work and will be useful (but maybe not:))

If you want to try dart server - please check [README](mcp_server_dart/README.md) for more details.

For dynamic registry of client tools and resources, please check [issue](https://github.com/Arenukvern/mcp_flutter/issues/32) - will update it during the work.

Have a nice day!

## 2.0.0

This release removes the forwarding server, devtools extension and refactors all communication to use Dart VM.

Note that setup is changed - see new [Quick Start](QUICK_START.md) and [Configuration](CONFIGURATION.md) docs.

The major change, is that now you can control what MCP Server will receive from your Flutter app.

This is made, by introducing new package - [mcp_toolkit](https://github.com/Arenukvern/mcp_flutter/tree/main/mcp_toolkit).

This package working on the same principle as WidgetBinding - it collects information from your Flutter app and sends it to Dart VM when MCP Server requests it.

You can override or add only tools you need.

For example, if you want to add Flutter tools, you can use `initializeFlutterToolkit()` method like one below.

```dart
MCPToolkitBinding.instance
  ..initialize()
  ..initializeFlutterToolkit();
```

## Poem

Thanks Code Rabbit for poem:

> A hop, a leap, the server's gone,  
> Now all through Dart VM, requests are drawn.  
> No more forwarding, no more relay,  
> Errors and screenshots come straight our way!  
> Toolkit in the app, so neat and spry,  
> Flutter views and details—oh my!  
> 🐇✨

## 1.0.0

Stable release with forwarding server and devtools extension.
