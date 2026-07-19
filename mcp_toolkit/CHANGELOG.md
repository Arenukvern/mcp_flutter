# 4.0.0-dev.7

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit prerelease train.

### Features

* **mcp_toolkit:** expose isSelected flag in semantic snapshot nodes ([64a35af](https://github.com/Arenukvern/mcp_flutter/commit/64a35afaec15b4e58d95bbbaa43a6be1d62fc092))


### Bug Fixes

* **mcp_toolkit:** don't double-dispatch tap on desktop when semantic action succeeds ([ab6fc27](https://github.com/Arenukvern/mcp_flutter/commit/ab6fc27239a5c92d527d1ce7582c00d0454c2572))
* **mcp_toolkit:** tap double-dispatch on desktop + expose isSelected in semantic snapshot ([af2da1a](https://github.com/Arenukvern/mcp_flutter/commit/af2da1a744953ad7188548ac9cf445a485f83d26))


### Documentation

* add dipsy as a contributor for code, and maintenance ([fea5eab](https://github.com/Arenukvern/mcp_flutter/commit/fea5eabe561479516f3e240220b8fdff5abbdf98))
* update .all-contributorsrc ([1f670f2](https://github.com/Arenukvern/mcp_flutter/commit/1f670f2d17ca1e554d3774f707525ca2dee498d6))
* update README.md ([d078171](https://github.com/Arenukvern/mcp_flutter/commit/d078171e8c50aebeb3d1572474ce1a83b0e19400))
* update star history chart to README ([46e5d89](https://github.com/Arenukvern/mcp_flutter/commit/46e5d8998055c75466d2b3b167abbc7e0fac5516))

# 4.0.0-dev.6

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit prerelease train.

# 4.0.0-dev.5

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit prerelease train.

# 4.0.0-dev.4

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit prerelease train.

# 4.0.0-dev.3

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit prerelease train.

# 4.0.0-dev.1

## [Unreleased]

### Changed

- Raised package Dart SDK floor to `>=3.12.0 <4.0.0`.
- Added Flutter SDK floor `>=3.44.0 <4.0.0` for Flutter package support.

## BREAKING CHANGES

- **Removed `MCPCallEntry`** from the public API. Use `AgentCallEntry` (re-exported by `mcp_toolkit` from hosted `intentcall_core`) for all dynamic tool/resource registration.
- **Removed** `mcp_call_entry_bridge.dart` and `MCPCallEntryAgentBridge.toAgentCallEntry()`.
- `MCPToolkitBinding.addEntries`, `bootstrapFlutter` `additionalEntries`, `addMcpTool`, and `AgentClientInstall.once` now take `AgentCallEntry` / `Set<AgentCallEntry>`.
- Built-in toolkits use `mcpToolkitTool` / `mcpToolkitResource` helpers when you still author with `MCPToolDefinition` / `MCPCallHandler` + `MCPCallResult`.

### Migration

See [intentcall Phase 6 migration](../docs/start_here/migration_mcp_call_entry_to_agent_call_entry.md) and run:

```bash
flutter-mcp-toolkit migrate agent-entries --check lib/
```

# 3.0.0

- Version alignment hard cut with Flutter MCP v3 release train.
- No API redesign in this cut; bump is release-line consistency for monorepo consumers.

# 0.4.0

- Dart SDK updated to 3.10.0 with all dependencies updated to the latest versions

- now VM service auto-reconnect when Flutter app restarts. Huge thank you to [@jkitching](https://github.com/jkitching) for PR! https://github.com/Arenukvern/mcp_flutter/pull/73

## 0.3.0

BREAKING CHANGES:

Dart SDK: 3.8.0

- chore: dart_mcp: ^0.3.3
- chore: from_json_to_json: ^0.3.0
- chore: lints: ^6.0.0
- chore: xsoulspace_lints: ^0.1.2

## 0.2.3

- perf: added more checks for [MCPCallEntry.resourceUri]

## 0.2.0

- Added `addMcpTool` function to add a single MCP tool to the MCP toolkit.

## BREAKING CHANGES

- Replaced `MCPCallEntry` with two constructors to create MCPCallEntry for resources and tools:
  - `MCPCallEntry.resource` to create MCPCallEntry for resources.
  - `MCPCallEntry.tool` to create MCPCallEntry for tools.
    This change simplifies the syntax by removing the need to write name of tool twice.
  - Now `MCPToolDefinition` has inputSchema as required parameter with `ObjectSchema` from `dart_mcp` package for better type safety. For example:
    ```dart
      definition: MCPToolDefinition(
        name: 'calculate_fibonacci',
        description: 'Calculate the nth Fibonacci number and return the sequence',
        inputSchema: ObjectSchema(
          properties: {
            'n': IntegerSchema(
              description: 'The position in the Fibonacci sequence (0-100)',
              minimum: 0,
              maximum: 100,
            ),
          },
          required: ['n'],
        ),
      ),
    ```

## 0.1.2

- Added `kDefaultMaxErrors` and `maxErrors` constants to `ErrorMonitor` class to limit number of errors stored.
- Added `kDebugMode` check to `MCPToolkitBinding.initialize` method.
- Added `kDebugMode` check to `MCPToolkitExtensions.initializeServiceExtensions` method.
- Added `kDebugMode` check to `MCPToolkitExtensions.registerServiceExtension` method to prevent adding entries in release mode.

## 0.1.1

- Fixed documentation.

## 0.1.0

- Initial release.
