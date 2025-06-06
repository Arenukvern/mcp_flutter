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

1. Removed extension and moved all logic for tools and resources to the client. (it's released alread as Dart MCPToolkit package)
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
