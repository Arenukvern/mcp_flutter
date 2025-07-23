# TODO: MCP Documentation Tools

## get_dart_member_doc (in mcp_server_dart)

- [x] Implemented as a Tool in mcp_server_dart/lib/src/mixins/handlers/doc_tools_handler.dart
- [x] Accepts 'member', returns stub for now
- [x] Registered in server dynamic registry
- [x] Moved to dedicated DocToolsHandler
- [x] **NEW: Implemented real functionality using VM Service Protocol:**
  1. ✅ Connect to running Flutter/Dart app using existing VM Service connection
  2. ✅ Use VM Service getClassList() API to discover classes in the running app
  3. ✅ Use VM Service getObject() to get detailed class information
  4. ✅ Extract and format documentation from class metadata
  5. ✅ Add caching for improved performance
  6. ✅ Handle different member types (classes, functions, variables)
  7. ✅ Support both library and app-specific members from the running isolate
  8. ✅ Add comprehensive error handling for:
     - Member not found
     - VM service connection issues
     - No running Flutter app
     - Isolate access problems
     - Timeout handling

**Key Benefits of Hybrid VM Service + LSP Approach:**

- ✅ **Primary**: Uses official Dart VM Service Protocol (same as used by IDEs)
- ✅ **Fallback**: Uses Dart LSP server for static analysis when VM Service unavailable
- ✅ Leverages existing VM service connection in the MCP server
- ✅ Gets documentation from the **running** Dart/Flutter app context (VM Service)
- ✅ Gets precise hover documentation and type info (LSP)
- ✅ Works with both user code and imported packages
- ✅ Provides rich class metadata including inheritance, interfaces, methods, fields
- ✅ **NEW**: Added tiny LSP client for `textDocument/hover` and `textDocument/definition`
- ✅ **NEW**: Support for position-based documentation lookup
- ✅ **NEW**: Automatic fallback when VM Service is not available

**Usage (VM Service + LSP Fallback):**

```json
{
  "name": "get_dart_member_doc",
  "arguments": {
    "member": "String",
    "isolate_id": "optional_isolate_id",
    "file_path": "optional_file_path_for_lsp_fallback",
    "line": "optional_line_number_for_hover",
    "character": "optional_character_position_for_hover"
  }
}
```

**Usage (Pure LSP Hover):**

```json
{
  "name": "get_dart_hover_doc",
  "arguments": {
    "file_path": "/path/to/file.dart",
    "line": 10,
    "character": 15
  }
}
```

## get_dart_hover_doc (NEW LSP-based tool)

- [x] ✅ **Created dedicated LSP-based hover documentation tool**
- [x] ✅ **Implemented tiny DartLspClient for Dart analysis server communication**
- [x] ✅ **Added support for textDocument/hover and textDocument/definition**
- [x] ✅ **Integrated LSP client with existing VM service workflow**
- [x] ✅ **Added position-based documentation lookup**
- [x] ✅ **Created example demonstrating LSP client usage**
- [x] ✅ **Added proper error handling and timeout management**
- [x] ✅ **Implemented automatic LSP server lifecycle management**

**LSP Client Features:**

- ✅ Starts Dart analysis server in LSP mode (`dart language-server`)
- ✅ Handles LSP protocol initialization and shutdown
- ✅ Supports `textDocument/hover` for documentation at specific positions
- ✅ Supports `textDocument/definition` for symbol navigation
- ✅ Automatic document opening and management
- ✅ JSON-RPC message handling with proper framing
- ✅ Response timeout and error handling
- ✅ Auto-detection of Dart executable location

**Usage:**

```json
{
  "name": "get_dart_hover_doc",
  "arguments": {
    "file_path": "/absolute/path/to/file.dart",
    "line": 10,
    "character": 15
  }
}
```

## General

- [x] ✅ **Switched from analysis_server_lib to VM Service Protocol approach**
- [x] ✅ **Created DartVmDocService for official VM service integration**
- [x] ✅ **Updated DocToolsHandler to use VM service**
- [x] ✅ **NEW: Implemented tiny LSP client for Dart analysis server access**
- [x] ✅ **NEW: Added hybrid VM Service + LSP approach**
- [x] ✅ **NEW: Created get_dart_hover_doc tool for precise position-based docs**
- [ ] Add integration tests for both VM Service and LSP documentation extraction
- [ ] Add support for more LSP methods (completion, signature help, etc.)
- [x] ✅ **Documentation works with live Flutter apps using existing connection**
