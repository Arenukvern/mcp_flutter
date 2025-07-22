# TODO: MCP Documentation Tools

## OnGetPubDocEntry

- [x] Design input/output schema for get_pub_doc tool
- [x] Implement handler logic:
  - [x] Accept package name (and optional version)
  - [x] Check if package is hosted (pub.dev): fetch README from pub.dev
  - [x] If git dependency: fetch README from git repo (assume URL is provided)
  - [x] If path dependency: read local README (assume path is provided)
  - [x] Fallback: search local pub cache for README
- [x] Register tool in `getFlutterMcpToolkitEntries`
- [x] Add concise documentation and usage examples
- [x] Test with hosted, git, and path dependencies

## OnGetDartMemberDocEntry

- [ ] Design input/output schema for get_dart_member_doc tool
- [ ] Implement handler logic (stub for now):
  - [ ] Accept member name (class/function/etc.)
  - [ ] Return placeholder or error (future: integrate with Dart Analysis Server)
- [ ] Register tool in `getFlutterMcpToolkitEntries`
- [ ] Add concise documentation and usage examples
- [ ] Plan for future integration with Dart Analysis Server
  - [ ] Research Dart Analysis Server protocol for symbol documentation
  - [ ] Implement file/offset resolution for member lookup
  - [ ] Integrate with analysis server for real docs

## General

- [ ] Export new tools if needed
- [ ] Ensure all code follows project conventions and is documented
