# TODO: MCP Documentation Tools

## OnGetPubDocEntry

- [ ] Design input/output schema for get_pub_doc tool
- [ ] Implement handler logic:
  - [ ] Accept package name (and optional version)
  - [ ] Check if package is hosted (pub.dev): fetch README from pub.dev
  - [ ] If git dependency: fetch README from git repo (assume URL is provided)
  - [ ] If path dependency: read local README (assume path is provided)
  - [ ] Fallback: search local pub cache for README
- [ ] Register tool in `getFlutterMcpToolkitEntries`
- [ ] Add concise documentation and usage examples
- [ ] Test with hosted, git, and path dependencies

## OnGetDartMemberDocEntry

- [ ] Design input/output schema for get_dart_member_doc tool
- [ ] Implement handler logic (stub for now):
  - [ ] Accept member name (class/function/etc.)
  - [ ] Return placeholder or error (future: integrate with Dart Analysis Server)
- [ ] Register tool in `getFlutterMcpToolkitEntries`
- [ ] Add concise documentation and usage examples
- [ ] Plan for future integration with Dart Analysis Server

## General

- [ ] Export new tools if needed
- [ ] Ensure all code follows project conventions and is documented
