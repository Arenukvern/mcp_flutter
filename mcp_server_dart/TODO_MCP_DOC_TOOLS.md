# TODO: MCP Documentation Tools

## get_dart_member_doc (in mcp_server_dart)

- [x] Implemented as a Tool in mcp_server_dart/lib/src/mixins/handlers/doc_tools_handler.dart
- [x] Accepts 'member', returns stub for now
- [x] Registered in server dynamic registry
- [x] Moved to dedicated DocToolsHandler
- [ ] Implement real functionality using Dart Analysis Server:
  1. Connect to the Dart Analysis Server using the analysis_server_client package
  2. Use getHover() API to fetch documentation for a given member
  3. Parse and format the documentation response
  4. Consider caching responses for performance
  5. Handle different member types (classes, functions, variables)
  6. Support both library and local project members
  7. Add error handling for:
     - Member not found
     - Analysis server connection issues
     - Invalid member format
     - Timeout handling

## General

- [ ] Add integration tests for Dart Analysis Server interaction
- [ ] Add documentation about Analysis Server setup requirements
