# TODO: MCP Documentation Tools

## get_pub_doc (in mcp_server_dart)

- [x] Implemented as a Tool in mcp_server_dart/lib/src/dynamic_registry/dynamic_registry_tools.dart
- [x] Accepts 'package' and optional 'fvm_sdk_path', fetches README from pub.dev or local pub cache
- [x] Returns README content and source
- [x] Registered in server dynamic registry
- [ ] (Optional) Add support for git/path dependencies in future

## get_dart_member_doc (in mcp_server_dart)

- [x] Implemented as a Tool in mcp_server_dart/lib/src/dynamic_registry/dynamic_registry_tools.dart
- [x] Accepts 'member', returns stub for now
- [x] Registered in server dynamic registry
- [ ] (Future) Integrate with Dart Analysis Server for real docs

## General

- [x] Removed toolkit-side implementations
- [ ] Ensure server-side tools are discoverable and tested
