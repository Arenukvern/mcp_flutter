# Tool Surface Inversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **SCOPE CHANGE 2026-04-29:** Live edit excised from v3.0.0. Tasks T3, T5, T7 (all live_edit
> related) are **deferred to post-v3.0.0**. v3.0.0 scope = T0, T1, T2, T4, T6, T8, T9, T10
> (core capability kernel + core tools only, no live_edit). The original task numbering is
> preserved below for reference; deferred tasks are marked accordingly.

**Goal (v3.0.0 scope):** Make `mcp_server_dart` and `flutter_mcp_cli` thin shells that compose the `mcp_capability_core` package. Tool names at the MCP boundary become prefixed by capability id (`core_tap_widget`). Live-edit capability deferred to post-v3.0.0 as `mcp_capability_live_edit`.

**Architecture:** Introduce a small `mcp_capability_kernel` contracts package (T1). Add capability machinery behind `--use-capability-kernel` flag (T2). Extract core tool glue into `mcp_capability_core` (T4). Extend `MCPToolkitBinding` to tag dynamic registrations (T6). Flip flag and delete legacy path (T8, T9). Docs + contracts (T10).

**Tech Stack:** Dart 3.11+, Flutter (app-side only), `dart_mcp ^0.5.0`, VM Service Protocol, DTD.

**Spec:** `todo/tool_surface_inversion.md` · **Audit:** `todo/v3_release_audit_2026-04-28.md`

---

## File Structure

### New packages

```
mcp_capability_kernel/                              # NEW — pure Dart, contracts only
  pubspec.yaml
  lib/
    mcp_capability_kernel.dart                      # public exports
    src/
      capability.dart                               # Capability interface
      capability_context.dart                      # CapabilityContext interface
      capability_config.dart                        # CapabilityConfig type
      tool_registration.dart                       # ToolRegistration value type
      resource_registration.dart                   # ResourceRegistration value type
      host_service.dart                            # HostService marker + family
      kernel_errors.dart                           # KernelError types
      validators.dart                              # id/prefix regex enforcement
  test/
    capability_test.dart
    capability_context_test.dart
    validators_test.dart

mcp_capability_core/                                # NEW — server-side glue, no Flutter
  pubspec.yaml
  lib/
    mcp_capability_core.dart                        # exports CoreCapability
    src/
      core_capability.dart                          # implements Capability
      tools/                                        # one file per tool group
        interaction_tools.dart                      # tap, enter, scroll, swipe, drag, hover, …
        inspection_tools.dart                       # view_screenshots, view_details, inspect_widget_at_point
        wait_tools.dart                             # wait_for + predicates
        navigation_tools.dart                       # press_key, handle_dialog, navigate
        form_tools.dart                             # fill_form
        log_tools.dart                              # get_recent_logs
        permission_tools.dart                       # permission toolkit tools
  test/
    core_capability_test.dart
    tools/
      interaction_tools_test.dart
      inspection_tools_test.dart
      …                                             # mirrors lib/src/tools/

flutter_live_edit/live_edit_models/                 # NEW — pure Dart, shared models
  pubspec.yaml
  lib/
    live_edit_models.dart                           # public exports
    src/
      commands.dart                                 # LiveEditCommand sealed class + variants
      results.dart                                  # CoreResult-shaped types specific to live edit
      session.dart                                  # session id + mode types
      selection.dart                                # selection candidate / state types
      panel.dart                                    # property panel types
      draft.dart                                    # draft / preview types
      agent_backend.dart                            # agent backend descriptors
  test/
    serialization_test.dart                         # round-trip JSON for every model

mcp_capability_live_edit/                           # NEW — server-side glue, no Flutter
  pubspec.yaml
  lib/
    mcp_capability_live_edit.dart                   # exports LiveEditCapability
    src/
      live_edit_capability.dart                     # implements Capability
      live_edit_host_bindings.dart                  # MOVED from mcp_server_dart/lib/src/capabilities/live_edit/
      live_edit_command_executor.dart               # MOVED + trimmed to host-needed commands
      agent/
        live_edit_agent_service.dart                # MOVED from flutter_live_edit_toolkit/lib/src/ai/agent/
  test/
    live_edit_capability_test.dart
    live_edit_command_executor_test.dart            # MOVED from mcp_server_dart/test/
```

### Modified packages

```
mcp_toolkit/mcp_toolkit/
  lib/src/mcp_toolkit_binding.dart                  # add `capabilityId` param to initialize()
  lib/src/mcp_toolkit_binding_base.dart             # plumb capabilityId into entry tagging
  lib/src/mcp_models.dart                           # extend MCPCallEntry with optional namespace
  test/binding_capability_id_test.dart              # NEW

mcp_server_dart/
  pubspec.yaml                                      # drop flutter_live_edit_toolkit + live_edit_tooling_ui_kit; add mcp_capability_kernel; default-bin gets mcp_capability_core + mcp_capability_live_edit
  bin/main.dart                                     # thin: register CoreCapability() + LiveEditCapability()
  bin/flutter_mcp_cli.dart                          # thin: same registration set
  lib/src/mcp_toolkit_server/host.dart              # NEW — McpHost, capability registrar
  lib/src/mcp_toolkit_server/server.dart            # behind flag: route tool dispatch through host registry
  lib/src/mcp_toolkit_server/dynamic_registry_bridge_impl.dart  # NEW — implements DynamicRegistryBridge from kernel
  lib/src/capabilities/live_edit/                   # DELETED (moved to mcp_capability_live_edit)
  lib/src/capabilities/{dart,error_analysis,visual_capture,diagnostics}/  # tool-definition files MOVED to mcp_capability_core
  lib/src/cli/cli_daemon_server.dart                # update bootstrap to use host

flutter_live_edit/flutter_live_edit_toolkit/
  pubspec.yaml                                      # depend on live_edit_models (replaces inline models)
  lib/src/models/live_edit_models.dart              # DELETED (re-export from live_edit_models package)
  lib/flutter_live_edit_toolkit.dart                # re-exports from live_edit_models
  lib/live_edit_runtime.dart                        # call MCPToolkitBinding.initialize(capabilityId: 'live_edit')
  lib/src/mcp_toolkit_tools/live_edit_tool_layer_glue.dart  # add 8 commands as MCPCallEntry registrations
  lib/src/ai/agent/live_edit_agent_service.dart     # DELETED (moved to mcp_capability_live_edit)

flutter_live_edit/live_edit_tooling_ui_kit/
  pubspec.yaml                                      # depend on live_edit_models
  lib/src/models/models.dart                        # re-export from live_edit_models for shared types

tool/contracts/
  check_plugin_surfaces.sh                          # update expected snapshot to prefixed names
  check_sdk_parity.sh                               # ensure Dockerfiles updated to dart:3.11.0-sdk
  expected_tool_surface.txt                         # NEW snapshot file with prefixed names

Dockerfile                                          # FROM dart:3.10.0-sdk → dart:3.11.0-sdk
Dockerfile.dev                                      # same
CHANGELOG.md                                        # rename table for v3.0.0
docs/MCP_RPC_DESCRIPTION.md                         # regenerated
```

### Parallelization map

| Task group | Depends on | Parallel with | v3.0.0? |
|---|---|---|---|
| **T0** Dockerfile fix | nothing | everything else | ✅ in scope |
| **T1** kernel package | nothing | — | ✅ in scope |
| **T2** host machinery (flag) | T1 | — | ✅ in scope |
| ~~**T3** `live_edit_models` extraction~~ | ~~nothing~~ | ~~T1~~ | ❌ **DEFERRED** (flutter_live_edit/ deleted) |
| **T4** `mcp_capability_core` | T1, T2 | — | ✅ in scope |
| ~~**T5** `mcp_capability_live_edit`~~ | ~~T1, T2, T3~~ | ~~T4~~ | ❌ **DEFERRED** |
| **T6** `MCPToolkitBinding.initialize(capabilityId)` | T2 | T4 | ✅ in scope |
| ~~**T7** `flutter_live_edit_toolkit` adoption~~ | ~~T3, T5, T6~~ | — | ❌ **DEFERRED** |
| **T8** flag flip | T1, T2, T4, T6 merged | — | ✅ in scope |
| **T9** delete legacy path | T8 | — | ✅ in scope |
| **T10** docs + contracts | T9 | — | ✅ in scope |

T0 is safe to dispatch in parallel with T1. T4 and T6 can run in parallel after T1+T2 land.
T3, T5, T7 are deferred — `flutter_live_edit/` was deleted in commit `d0a11c9`.

---

## Task T0: Fix Dockerfile SDK pin (release blocker)

**Files:**
- Modify: `Dockerfile:1`
- Modify: `Dockerfile.dev:1`

- [ ] **Step T0.1: Update Dockerfile to dart:3.11.0-sdk**

```bash
# Read current first line of each Dockerfile to locate the FROM
head -1 Dockerfile
head -1 Dockerfile.dev
```

Edit both: `FROM dart:3.10.0-sdk` → `FROM dart:3.11.0-sdk`.

- [ ] **Step T0.2: Verify contracts pass**

Run: `make check-contracts`
Expected: All four checks (sdk parity, error code playbook, docs drift, plugin surfaces) report PASS, no non-zero exit. If `check_plugin_surfaces.sh` fails for unrelated reasons, capture the output for triage but mark T0 done — only the SDK parity check is in scope here.

- [ ] **Step T0.3: Commit**

```bash
git add Dockerfile Dockerfile.dev
git commit -m "fix(release): bump Dockerfile SDK pin to dart:3.11.0-sdk"
```

**Done when:** `bash tool/contracts/check_sdk_parity.sh` exits zero.

---

## Task T1: `mcp_capability_kernel` package

This is the contracts-only package. No host, no transport, no Flutter. Pure Dart. Every other package depends on it — but it depends on nothing except `dart_mcp` and `meta`.

### T1.1: Scaffold package

**Files:**
- Create: `mcp_capability_kernel/pubspec.yaml`
- Create: `mcp_capability_kernel/analysis_options.yaml`
- Create: `mcp_capability_kernel/lib/mcp_capability_kernel.dart`

- [ ] **Step T1.1.1: Create pubspec.yaml**

```yaml
# mcp_capability_kernel/pubspec.yaml
name: mcp_capability_kernel
description: >-
  Contracts package for composable MCP capability units. Defines the Capability
  interface, CapabilityContext, and HostService family. Pure Dart; no Flutter,
  no transport.
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.11.0

dependencies:
  dart_mcp: ^0.5.0
  meta: ^1.17.0

dev_dependencies:
  test: ^1.25.0
  lints: ^6.1.0
```

- [ ] **Step T1.1.2: Create analysis_options.yaml**

```yaml
include: package:lints/recommended.yaml

linter:
  rules:
    avoid_print: true
    prefer_final_locals: true
    sort_pub_dependencies: true
```

- [ ] **Step T1.1.3: Create the export barrel**

```dart
// mcp_capability_kernel/lib/mcp_capability_kernel.dart
/// Contracts for composable MCP capability units.
///
/// A [Capability] is a unit of MCP functionality (a set of tools and/or
/// resources) that can be loaded into a host (server or CLI). Capabilities
/// register their surface through a [CapabilityContext] supplied by the host;
/// the kernel applies a `<capabilityId>_` prefix to all exposed names.
library mcp_capability_kernel;

export 'src/capability.dart';
export 'src/capability_config.dart';
export 'src/capability_context.dart';
export 'src/host_service.dart';
export 'src/kernel_errors.dart';
export 'src/resource_registration.dart';
export 'src/tool_registration.dart';
```

- [ ] **Step T1.1.4: Verify pub get works**

Run:
```bash
cd mcp_capability_kernel && dart pub get
```
Expected: resolves cleanly, no `Got dependencies!` errors.

- [ ] **Step T1.1.5: Commit**

```bash
git add mcp_capability_kernel
git commit -m "feat(kernel): scaffold mcp_capability_kernel package"
```

### T1.2: Define `Capability` and `CapabilityContext`

**Files:**
- Create: `mcp_capability_kernel/lib/src/capability.dart`
- Create: `mcp_capability_kernel/lib/src/capability_context.dart`
- Create: `mcp_capability_kernel/lib/src/capability_config.dart`
- Create: `mcp_capability_kernel/lib/src/tool_registration.dart`
- Create: `mcp_capability_kernel/lib/src/resource_registration.dart`
- Create: `mcp_capability_kernel/lib/src/host_service.dart`
- Create: `mcp_capability_kernel/lib/src/kernel_errors.dart`

- [ ] **Step T1.2.1: Write tool_registration.dart**

```dart
// mcp_capability_kernel/lib/src/tool_registration.dart
import 'package:dart_mcp/server.dart';
import 'package:meta/meta.dart';

/// A tool the capability wants the host to expose.
///
/// [name] is the bare name (without prefix). The host applies the
/// `<capabilityId>_` prefix when publishing to MCP clients.
@immutable
final class ToolRegistration {
  const ToolRegistration({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final Future<CallToolResult> Function(CallToolRequest request) handler;
}
```

- [ ] **Step T1.2.2: Write resource_registration.dart**

```dart
// mcp_capability_kernel/lib/src/resource_registration.dart
import 'package:dart_mcp/server.dart';
import 'package:meta/meta.dart';

/// A resource the capability wants the host to expose.
///
/// [uri] is the bare URI; the host may rewrite the authority/path according
/// to the capability namespace policy. Resource handlers are not prefixed
/// (URIs are already namespaced).
@immutable
final class ResourceRegistration {
  const ResourceRegistration({
    required this.uri,
    required this.name,
    required this.description,
    required this.mimeType,
    required this.handler,
  });

  final String uri;
  final String name;
  final String description;
  final String mimeType;
  final Future<ReadResourceResult> Function(ReadResourceRequest request)
  handler;
}
```

- [ ] **Step T1.2.3: Write host_service.dart**

```dart
// mcp_capability_kernel/lib/src/host_service.dart
/// Marker interface for host-provided services that capabilities can require.
///
/// Capabilities resolve services through [CapabilityContext.require] at
/// registration time. Concrete implementations live in `mcp_server_dart`;
/// the kernel only defines the interfaces.
abstract interface class HostService {}

/// Bridge to the dynamic-registry that surfaces app-side
/// `MCPToolkitBinding.addEntries` registrations as MCP tools.
///
/// A capability that wants to expose its app-side tools under its own
/// namespace calls [claim] during [Capability.register]. Subsequent dynamic
/// entries tagged with the same namespace are exposed with the
/// `<namespace>_` prefix.
abstract interface class DynamicRegistryBridge implements HostService {
  /// Reserve a namespace. Throws [StateError] if the namespace is already
  /// claimed by a different capability.
  void claim({required String namespace});
}

/// Read-only access to the running Flutter app's VM service. Capabilities
/// that need to invoke service extensions go through this.
abstract interface class VmServiceClient implements HostService {
  /// Invoke a service extension on the running app, returning the raw
  /// response map.
  Future<Map<String, Object?>> callServiceExtension(
    final String method, {
    final Map<String, Object?>? args,
  });
}

/// Hot-reload coordinator. Capabilities that orchestrate code generation
/// + reload (live-edit) request reloads through this.
abstract interface class HotReloadCoordinator implements HostService {
  Future<HotReloadResult> reload({final bool pause = false});
}

/// Result of [HotReloadCoordinator.reload].
final class HotReloadResult {
  const HotReloadResult({required this.success, this.message});
  final bool success;
  final String? message;
}
```

- [ ] **Step T1.2.4: Write capability_config.dart**

```dart
// mcp_capability_kernel/lib/src/capability_config.dart
import 'package:meta/meta.dart';

/// Capability-scoped configuration parsed from CLI flags or config file.
///
/// The host parses the full CLI arg set, then hands each capability its
/// scoped slice. Unknown keys are ignored (capabilities can evolve their
/// config independently).
@immutable
final class CapabilityConfig {
  const CapabilityConfig({final Map<String, Object?>? values})
    : _values = values ?? const <String, Object?>{};

  final Map<String, Object?> _values;

  T? get<T>(final String key) {
    final value = _values[key];
    if (value is T) return value;
    return null;
  }

  bool getBool(final String key, {final bool defaultValue = false}) =>
      get<bool>(key) ?? defaultValue;

  String? getString(final String key) => get<String>(key);

  int? getInt(final String key) => get<int>(key);
}
```

- [ ] **Step T1.2.5: Write kernel_errors.dart**

```dart
// mcp_capability_kernel/lib/src/kernel_errors.dart
/// Base type for kernel-detected misconfiguration.
sealed class KernelError extends Error {
  KernelError(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

/// Capability id is invalid or reserved.
final class InvalidCapabilityIdError extends KernelError {
  InvalidCapabilityIdError(super.message);
}

/// Tool name passed to registerTool already starts with the capability prefix
/// (capabilities must register bare names).
final class PrePrefixedToolNameError extends KernelError {
  PrePrefixedToolNameError(super.message);
}

/// Two registrations resolve to the same fully-qualified name.
final class ToolNameCollisionError extends KernelError {
  ToolNameCollisionError(super.message);
}

/// register() called twice on the same capability for the same host.
final class CapabilityAlreadyRegisteredError extends KernelError {
  CapabilityAlreadyRegisteredError(super.message);
}

/// require<T>() called for a service the host didn't provide.
final class HostServiceUnavailableError extends KernelError {
  HostServiceUnavailableError(super.message);
}
```

- [ ] **Step T1.2.6: Write capability_context.dart**

```dart
// mcp_capability_kernel/lib/src/capability_context.dart
import 'package:meta/meta.dart';

import 'capability_config.dart';
import 'host_service.dart';
import 'resource_registration.dart';
import 'tool_registration.dart';

/// What the host hands a [Capability] when calling `register()`.
///
/// Capabilities use this to declare their surface and resolve host services.
/// The context is per-capability and per-registration; capabilities should
/// not retain it past `register()`.
abstract interface class CapabilityContext {
  /// The capability's id. Convenience copy; equal to the capability's id.
  String get capabilityId;

  /// Capability-scoped configuration.
  CapabilityConfig get config;

  /// Register an MCP tool. The kernel applies the `<capabilityId>_` prefix
  /// to [registration.name] before exposing it; capabilities must NOT
  /// pre-prefix.
  ///
  /// Throws [PrePrefixedToolNameError] if [registration.name] starts with
  /// the capability prefix. Throws [ToolNameCollisionError] if another
  /// registration with the same final name exists.
  void registerTool(final ToolRegistration registration);

  /// Register an MCP resource. URIs are not prefixed by the kernel
  /// (URIs already encode their authority).
  void registerResource(final ResourceRegistration registration);

  /// Resolve a host service the capability needs.
  ///
  /// Throws [HostServiceUnavailableError] if the host did not provide
  /// an instance for [T].
  T require<T extends HostService>();

  /// Optional logger sink. Implementation-defined.
  void log(final String message, {final LogLevel level = LogLevel.info});
}

enum LogLevel { trace, debug, info, warning, error }
```

- [ ] **Step T1.2.7: Write capability.dart**

```dart
// mcp_capability_kernel/lib/src/capability.dart
import 'capability_context.dart';

/// A unit of MCP functionality that a host (server or CLI) can load.
///
/// Implementations are stateless types; per-host state lives on the host
/// side, accessed via [CapabilityContext.require].
abstract interface class Capability {
  /// Stable id used for the tool-name prefix (`<id>_<tool>`) and for
  /// configuration. Must match `^[a-z][a-z0-9_]*$`. Examples: `core`,
  /// `live_edit`. Reserved: `app` (used for unscoped dynamic registrations).
  String get id;

  /// Human-readable description, surfaced in `--list-capabilities` output.
  String get description;

  /// Semver of this capability package, surfaced in `doctor` output.
  String get version;

  /// Called once at host startup. Register tools, resources, and
  /// host-service claims here. Calling twice on the same host throws
  /// [CapabilityAlreadyRegisteredError]. Must not perform I/O.
  Future<void> register(final CapabilityContext context);

  /// Called once at host shutdown. Release resources, cancel subscriptions.
  Future<void> dispose();
}
```

- [ ] **Step T1.2.8: Verify analyze passes**

Run:
```bash
cd mcp_capability_kernel && dart analyze
```
Expected: `No issues found!`

- [ ] **Step T1.2.9: Commit**

```bash
git add mcp_capability_kernel
git commit -m "feat(kernel): define Capability + CapabilityContext + HostService contracts"
```

### T1.3: Validators (id + prefix enforcement, TDD)

**Files:**
- Create: `mcp_capability_kernel/lib/src/validators.dart`
- Create: `mcp_capability_kernel/test/validators_test.dart`

- [ ] **Step T1.3.1: Write the failing test**

```dart
// mcp_capability_kernel/test/validators_test.dart
import 'package:mcp_capability_kernel/src/kernel_errors.dart';
import 'package:mcp_capability_kernel/src/validators.dart';
import 'package:test/test.dart';

void main() {
  group('validateCapabilityId', () {
    test('accepts lowercase alphanumeric with underscores', () {
      validateCapabilityId('core');
      validateCapabilityId('live_edit');
      validateCapabilityId('a');
      validateCapabilityId('a1');
      validateCapabilityId('snake_case_123');
    });

    test('rejects empty', () {
      expect(
        () => validateCapabilityId(''),
        throwsA(isA<InvalidCapabilityIdError>()),
      );
    });

    test('rejects leading digit', () {
      expect(
        () => validateCapabilityId('1foo'),
        throwsA(isA<InvalidCapabilityIdError>()),
      );
    });

    test('rejects uppercase', () {
      expect(
        () => validateCapabilityId('LiveEdit'),
        throwsA(isA<InvalidCapabilityIdError>()),
      );
    });

    test('rejects hyphen and dot', () {
      expect(
        () => validateCapabilityId('live-edit'),
        throwsA(isA<InvalidCapabilityIdError>()),
      );
      expect(
        () => validateCapabilityId('live.edit'),
        throwsA(isA<InvalidCapabilityIdError>()),
      );
    });

    test('rejects reserved id "app"', () {
      expect(
        () => validateCapabilityId('app'),
        throwsA(isA<InvalidCapabilityIdError>()),
      );
    });
  });

  group('validateBareToolName', () {
    test('accepts a name that does not start with the capability prefix', () {
      validateBareToolName(capabilityId: 'core', name: 'tap_widget');
      validateBareToolName(capabilityId: 'live_edit', name: 'select');
    });

    test('rejects a name that starts with the capability prefix', () {
      expect(
        () =>
            validateBareToolName(capabilityId: 'core', name: 'core_tap_widget'),
        throwsA(isA<PrePrefixedToolNameError>()),
      );
      expect(
        () => validateBareToolName(capabilityId: 'live_edit', name: 'live_edit_select'),
        throwsA(isA<PrePrefixedToolNameError>()),
      );
    });

    test('accepts coincidental prefix-suffix overlap', () {
      // 'core_thing' from a capability with id 'foo' — fine, prefix is 'foo_'
      validateBareToolName(capabilityId: 'foo', name: 'core_thing');
    });
  });

  group('applyPrefix', () {
    test('joins capability id and bare name with underscore', () {
      expect(
        applyPrefix(capabilityId: 'core', name: 'tap_widget'),
        'core_tap_widget',
      );
      expect(
        applyPrefix(capabilityId: 'live_edit', name: 'select'),
        'live_edit_select',
      );
    });
  });
}
```

- [ ] **Step T1.3.2: Run the test, verify it fails**

Run:
```bash
cd mcp_capability_kernel && dart test test/validators_test.dart
```
Expected: FAIL with "Target of URI doesn't exist: 'package:mcp_capability_kernel/src/validators.dart'".

- [ ] **Step T1.3.3: Implement validators.dart**

```dart
// mcp_capability_kernel/lib/src/validators.dart
import 'kernel_errors.dart';

const _reservedCapabilityIds = <String>{'app'};
final _capabilityIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// Throws [InvalidCapabilityIdError] if [id] is empty, malformed, or
/// reserved.
void validateCapabilityId(final String id) {
  if (id.isEmpty) {
    throw InvalidCapabilityIdError('Capability id must not be empty.');
  }
  if (!_capabilityIdPattern.hasMatch(id)) {
    throw InvalidCapabilityIdError(
      'Capability id "$id" must match ^[a-z][a-z0-9_]*\$.',
    );
  }
  if (_reservedCapabilityIds.contains(id)) {
    throw InvalidCapabilityIdError(
      'Capability id "$id" is reserved (used internally for unscoped '
      'dynamic registrations).',
    );
  }
}

/// Throws [PrePrefixedToolNameError] if [name] starts with
/// `<capabilityId>_`.
void validateBareToolName({
  required final String capabilityId,
  required final String name,
}) {
  final prefix = '${capabilityId}_';
  if (name.startsWith(prefix)) {
    throw PrePrefixedToolNameError(
      'Tool name "$name" must not start with the capability prefix '
      '"$prefix"; pass the bare name and let the kernel apply the prefix.',
    );
  }
}

/// Returns `<capabilityId>_<name>`.
String applyPrefix({
  required final String capabilityId,
  required final String name,
}) => '${capabilityId}_$name';
```

- [ ] **Step T1.3.4: Re-export validators from the barrel**

Edit `mcp_capability_kernel/lib/mcp_capability_kernel.dart`:

```dart
export 'src/validators.dart' show applyPrefix;
```

(Internal validators stay private to the kernel; only `applyPrefix` is exported for host implementations to use.)

- [ ] **Step T1.3.5: Run the tests, verify they pass**

Run:
```bash
cd mcp_capability_kernel && dart test test/validators_test.dart
```
Expected: All 11 tests pass.

- [ ] **Step T1.3.6: Commit**

```bash
git add mcp_capability_kernel
git commit -m "feat(kernel): id + prefix validators with full test coverage"
```

### T1.4: End-of-T1 checkpoint

- [ ] **Step T1.4.1: Run all kernel tests**

Run:
```bash
cd mcp_capability_kernel && dart test
```
Expected: green.

- [ ] **Step T1.4.2: Run analyze**

Run:
```bash
cd mcp_capability_kernel && dart analyze
```
Expected: `No issues found!`

- [ ] **Step T1.4.3: User checkpoint**

Pause. Surface to user: "T1 (kernel package) complete. Ready to start T2 (host machinery in server)?"

**Done when:** package builds, all tests pass, analyze clean, user signs off.

---

## Task T2: Server-side host machinery, behind feature flag

`mcp_server_dart` learns to load and dispatch through `Capability` instances. Behind `--use-capability-kernel` flag (default off). Legacy registration path unchanged.

### T2.1: Add kernel dependency

**Files:**
- Modify: `mcp_server_dart/pubspec.yaml`

- [ ] **Step T2.1.1: Add path dependency**

Add to `dependencies:` block:
```yaml
  mcp_capability_kernel:
    path: ../mcp_capability_kernel
```

- [ ] **Step T2.1.2: Resolve**

Run: `cd mcp_server_dart && dart pub get`
Expected: resolves successfully.

- [ ] **Step T2.1.3: Commit**

```bash
git add mcp_server_dart/pubspec.yaml mcp_server_dart/pubspec.lock
git commit -m "chore(server): add path dep on mcp_capability_kernel"
```

### T2.2: McpHost — capability registry on the server

**Files:**
- Create: `mcp_server_dart/lib/src/mcp_toolkit_server/host.dart`
- Create: `mcp_server_dart/test/host_test.dart`

- [ ] **Step T2.2.1: Write the failing host registration test**

```dart
// mcp_server_dart/test/host_test.dart
import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/host.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:test/test.dart';

final class _FakeCapability implements Capability {
  _FakeCapability({
    required this.id,
    required this.tools,
  });

  @override
  final String id;
  @override
  String get description => 'fake';
  @override
  String get version => '0.0.0';

  final List<String> tools;

  @override
  Future<void> register(final CapabilityContext context) async {
    for (final name in tools) {
      context.registerTool(
        ToolRegistration(
          name: name,
          description: 'fake tool $name',
          inputSchema: const {'type': 'object'},
          handler: (_) async => CallToolResult(
            content: const [TextContent(text: 'ok')],
          ),
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('McpHost', () {
    test('registers a capability and exposes prefixed tool names', () async {
      final host = McpHost();
      await host.registerCapability(
        _FakeCapability(id: 'core', tools: ['tap_widget', 'enter_text']),
      );

      expect(
        host.toolNames,
        containsAll(<String>['core_tap_widget', 'core_enter_text']),
      );
    });

    test('rejects two capabilities with the same id', () async {
      final host = McpHost();
      await host.registerCapability(_FakeCapability(id: 'core', tools: []));
      await expectLater(
        host.registerCapability(_FakeCapability(id: 'core', tools: [])),
        throwsA(isA<CapabilityAlreadyRegisteredError>()),
      );
    });

    test('rejects a capability that pre-prefixes its tool names', () async {
      final host = McpHost();
      await expectLater(
        host.registerCapability(
          _FakeCapability(id: 'core', tools: ['core_tap_widget']),
        ),
        throwsA(isA<PrePrefixedToolNameError>()),
      );
    });

    test('rejects a tool-name collision across capabilities', () async {
      // Two capabilities both register a tool that produces the same final
      // name. Trivially this requires shared id (impossible by construction)
      // OR a degenerate case where the prefixes collide. We construct one:
      // capability id 'core' with tool 'thing' → 'core_thing'.
      // Then capability id 'core_thing' with tool '' is invalid by id rules.
      // So the realistic collision is intra-capability — same name twice.
      final host = McpHost();
      await expectLater(
        host.registerCapability(
          _FakeCapability(id: 'core', tools: ['tap_widget', 'tap_widget']),
        ),
        throwsA(isA<ToolNameCollisionError>()),
      );
    });

    test('require<T>() throws when host service not provided', () async {
      final host = McpHost();
      late CapabilityContext capturedContext;

      final cap = _CapturingCapability((ctx) {
        capturedContext = ctx;
      });

      await host.registerCapability(cap);
      expect(
        () => capturedContext.require<DynamicRegistryBridge>(),
        throwsA(isA<HostServiceUnavailableError>()),
      );
    });
  });
}

final class _CapturingCapability implements Capability {
  _CapturingCapability(this._capture);
  final void Function(CapabilityContext context) _capture;

  @override
  String get id => 'capture';
  @override
  String get description => 'capture';
  @override
  String get version => '0.0.0';

  @override
  Future<void> register(final CapabilityContext context) async {
    _capture(context);
  }

  @override
  Future<void> dispose() async {}
}
```

- [ ] **Step T2.2.2: Run test, verify failure**

Run:
```bash
cd mcp_server_dart && dart test test/host_test.dart
```
Expected: FAIL on missing `host.dart`.

- [ ] **Step T2.2.3: Implement McpHost**

```dart
// mcp_server_dart/lib/src/mcp_toolkit_server/host.dart
// ignore_for_file: public_member_api_docs
import 'dart:async';

import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

/// Per-host registry of loaded [Capability] instances and the tools/resources
/// they registered.
final class McpHost {
  McpHost({final Map<Type, HostService>? services})
    : _services = services ?? const <Type, HostService>{};

  final Map<Type, HostService> _services;
  final Map<String, _LoadedCapability> _capabilities =
      <String, _LoadedCapability>{};
  final Map<String, _RegisteredTool> _tools = <String, _RegisteredTool>{};

  Iterable<String> get toolNames => _tools.keys;

  Future<void> registerCapability(final Capability capability) async {
    validateCapabilityId(capability.id); // throws InvalidCapabilityIdError
    if (_capabilities.containsKey(capability.id)) {
      throw CapabilityAlreadyRegisteredError(
        'Capability id "${capability.id}" already registered.',
      );
    }

    final loaded = _LoadedCapability(capability);
    _capabilities[capability.id] = loaded;

    final ctx = _HostCapabilityContext(host: this, capability: capability);
    try {
      await capability.register(ctx);
    } finally {
      ctx.sealed = true;
    }
  }

  void _registerTool({
    required final String capabilityId,
    required final ToolRegistration registration,
  }) {
    validateBareToolName(
      capabilityId: capabilityId,
      name: registration.name,
    );
    final fullName = applyPrefix(
      capabilityId: capabilityId,
      name: registration.name,
    );
    if (_tools.containsKey(fullName)) {
      throw ToolNameCollisionError(
        'Tool "$fullName" registered twice.',
      );
    }
    _tools[fullName] = _RegisteredTool(
      capabilityId: capabilityId,
      registration: registration,
    );
  }

  T _require<T extends HostService>() {
    final service = _services[T];
    if (service == null) {
      throw HostServiceUnavailableError(
        'Host service of type $T was not provided.',
      );
    }
    return service as T;
  }

  Future<void> dispose() async {
    for (final loaded in _capabilities.values) {
      await loaded.capability.dispose();
    }
    _capabilities.clear();
    _tools.clear();
  }
}

// re-exported from kernel for callers
final class _LoadedCapability {
  _LoadedCapability(this.capability);
  final Capability capability;
}

final class _RegisteredTool {
  _RegisteredTool({required this.capabilityId, required this.registration});
  final String capabilityId;
  final ToolRegistration registration;
}

final class _HostCapabilityContext implements CapabilityContext {
  _HostCapabilityContext({required this.host, required this.capability});

  final McpHost host;
  final Capability capability;
  bool sealed = false;

  @override
  String get capabilityId => capability.id;

  @override
  CapabilityConfig get config => const CapabilityConfig();

  @override
  void registerTool(final ToolRegistration registration) {
    _ensureNotSealed();
    host._registerTool(
      capabilityId: capability.id,
      registration: registration,
    );
  }

  @override
  void registerResource(final ResourceRegistration registration) {
    _ensureNotSealed();
    // Resources unimplemented in this PR; tracked for T8.
    throw UnimplementedError('registerResource not yet wired.');
  }

  @override
  T require<T extends HostService>() => host._require<T>();

  @override
  void log(final String message, {final LogLevel level = LogLevel.info}) {
    // ignore: avoid_print
    print('[${capability.id}] $message');
  }

  void _ensureNotSealed() {
    if (sealed) {
      throw StateError(
        'CapabilityContext for "${capability.id}" used after register() '
        'returned. Capabilities must register synchronously.',
      );
    }
  }
}
```

The validators (`validateCapabilityId`, `validateBareToolName`) are imported but the kernel currently exports only `applyPrefix`. Add re-export of validators to the kernel barrel for host use, or replicate them — the cleaner path is to re-export. Edit `mcp_capability_kernel/lib/mcp_capability_kernel.dart`:

```dart
export 'src/validators.dart';
```

(Replaces the `show applyPrefix` line.)

- [ ] **Step T2.2.4: Re-run test, verify pass**

Run:
```bash
cd mcp_server_dart && dart test test/host_test.dart
```
Expected: all 5 tests pass.

- [ ] **Step T2.2.5: Commit**

```bash
git add mcp_capability_kernel/lib/mcp_capability_kernel.dart \
  mcp_server_dart/lib/src/mcp_toolkit_server/host.dart \
  mcp_server_dart/test/host_test.dart
git commit -m "feat(server): McpHost capability registrar with prefix + collision enforcement"
```

### T2.3: Feature flag wiring

**Files:**
- Modify: `mcp_server_dart/lib/src/mcp_toolkit_server/server.dart`
- Modify: `mcp_server_dart/bin/main.dart`

- [ ] **Step T2.3.1: Read current main.dart**

Run:
```bash
cat mcp_server_dart/bin/main.dart
```

Identify where CLI args are parsed (likely `args` package). Locate the configuration construction.

- [ ] **Step T2.3.2: Add `--use-capability-kernel` flag**

Add to the existing `ArgParser`:
```dart
parser.addFlag(
  'use-capability-kernel',
  defaultsTo: false,
  help:
      'EXPERIMENTAL: route tool registrations through mcp_capability_kernel. '
      'When off, the legacy static registration path is used.',
);
```

Plumb the parsed flag into the server configuration as a new field `bool useCapabilityKernel`.

- [ ] **Step T2.3.3: Wire McpHost when flag is on**

In `server.dart` constructor / setup, when `configuration.useCapabilityKernel` is true:

```dart
if (configuration.useCapabilityKernel) {
  _host = McpHost();
  // Capability registration happens in main.dart; server just owns
  // dispatch routing.
} else {
  _host = null;
}
```

Add a routing branch in tool dispatch: if `_host != null` and the requested tool name resolves through `_host.toolNames`, dispatch through the host registration's handler. Otherwise fall through to the existing legacy path.

(Specific dispatch wiring depends on how `dart_mcp`'s `MCPServer` is set up in `BaseMCPToolkitServer`. Read the existing pattern; do not invent new pluggable hooks if they are already there.)

- [ ] **Step T2.3.4: Add a no-op test that the server starts with the flag on**

Test file: `mcp_server_dart/test/host_flag_smoke_test.dart`

```dart
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/server.dart';
// import the configuration type and stream channel mock helpers as needed
import 'package:test/test.dart';

void main() {
  test('server starts with --use-capability-kernel flag set', () async {
    // Construct a server instance with a mock stream channel and
    // configuration.useCapabilityKernel = true. Assert no exceptions
    // thrown during construction.
    // (Concrete construction depends on test helpers in the existing suite;
    // mirror the pattern in test/p1_commands_test.dart or similar.)
  });
}
```

Fill in the construction using existing test helpers — read e.g. `mcp_server_dart/test/p1_commands_test.dart` for the pattern.

- [ ] **Step T2.3.5: Run smoke test**

Run:
```bash
cd mcp_server_dart && dart test test/host_flag_smoke_test.dart
```
Expected: pass.

- [ ] **Step T2.3.6: Run full test suite to verify nothing regressed**

Run:
```bash
cd mcp_server_dart && flutter test
```
Expected: all existing tests still pass (legacy path is default).

- [ ] **Step T2.3.7: Commit**

```bash
git add mcp_server_dart
git commit -m "feat(server): wire --use-capability-kernel flag with McpHost dispatch (default off)"
```

### T2.4: End-of-T2 checkpoint

- [ ] **Step T2.4.1: Run full mcp_server_dart suite**

Run: `cd mcp_server_dart && flutter test`
Expected: green.

- [ ] **Step T2.4.2: User checkpoint**

"T2 (host machinery behind flag) complete. Ready to dispatch T3 (`live_edit_models` extraction) as a separate agent in parallel with T4?"

---

## Task T3: Extract `live_edit_models` package (parallelizable separate agent)

This task is self-contained and has no dependency on T1/T2. It can be dispatched to a separate agent. Its sole purpose: pull all models currently in `flutter_live_edit_toolkit/lib/src/models/` and `live_edit_tooling_ui_kit/lib/src/models/` into a new pure-Dart package, then have both packages re-export from it. Net result: `mcp_server_dart` (after T5) can depend on `live_edit_models` instead of the Flutter packages.

### T3.1: Inventory the current model surface

- [ ] **Step T3.1.1: List models in flutter_live_edit_toolkit**

Run:
```bash
ls flutter_live_edit/flutter_live_edit_toolkit/lib/src/models/
cat flutter_live_edit/flutter_live_edit_toolkit/lib/src/models/live_edit_models.dart | head -200
```

- [ ] **Step T3.1.2: List models in live_edit_tooling_ui_kit**

Run:
```bash
ls flutter_live_edit/live_edit_tooling_ui_kit/lib/src/models/
```

- [ ] **Step T3.1.3: Identify which types the server reaches into**

Run:
```bash
grep -rn "package:flutter_live_edit_toolkit/src/models\|package:live_edit_tooling_ui_kit/src/models" \
  mcp_server_dart/lib/ --include="*.dart"
```

The output is the set of types that **must** end up in `live_edit_models` (server's import set is the constraint).

- [ ] **Step T3.1.4: Identify Flutter dependencies in those models**

For each file in the model directories, grep for `package:flutter/` imports. Pure-Dart models can move directly; Flutter-tainted files need a split (move pure parts to `live_edit_models`, keep Flutter parts in the original package).

- [ ] **Step T3.1.5: Commit the inventory as a checklist**

Save the mapping to `flutter_live_edit/live_edit_models/MIGRATION_INVENTORY.md` so the rest of T3 has a clear target. (This file is deleted at end of T3.)

### T3.2: Scaffold `live_edit_models` package

**Files:**
- Create: `flutter_live_edit/live_edit_models/pubspec.yaml`
- Create: `flutter_live_edit/live_edit_models/analysis_options.yaml`
- Create: `flutter_live_edit/live_edit_models/lib/live_edit_models.dart`

- [ ] **Step T3.2.1: pubspec.yaml**

```yaml
name: live_edit_models
description: >-
  Pure-Dart models shared between flutter_live_edit_toolkit, live_edit_tooling_ui_kit,
  and the server-side mcp_capability_live_edit. Contains zero Flutter imports.
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.11.0

dependencies:
  collection: ^1.19.1
  equatable: ^2.0.8
  freezed_annotation: ^3.1.0
  from_json_to_json: ^0.5.0
  json_annotation: ^4.11.0
  meta: ^1.17.0

dev_dependencies:
  build_runner: ^2.13.1
  freezed: ^3.1.0
  json_serializable: ^6.10.0
  test: ^1.25.0
  lints: ^6.1.0
```

- [ ] **Step T3.2.2: analysis_options.yaml** — copy from `flutter_live_edit/flutter_live_edit_toolkit/analysis_options.yaml`.

- [ ] **Step T3.2.3: Empty barrel**

```dart
// flutter_live_edit/live_edit_models/lib/live_edit_models.dart
/// Pure-Dart models shared across the live-edit subsystem.
library live_edit_models;

// Exports added as files are migrated in T3.3.
```

- [ ] **Step T3.2.4: Resolve**

Run: `cd flutter_live_edit/live_edit_models && dart pub get`
Expected: success.

- [ ] **Step T3.2.5: Commit**

```bash
git add flutter_live_edit/live_edit_models
git commit -m "feat(live_edit_models): scaffold pure-Dart shared models package"
```

### T3.3: Migrate each model file

For each file identified in T3.1's inventory:

- [ ] **Step T3.3.x.1**: Move file from `flutter_live_edit/flutter_live_edit_toolkit/lib/src/models/<file>.dart` to `flutter_live_edit/live_edit_models/lib/src/<file>.dart`.

- [ ] **Step T3.3.x.2**: Update imports in the moved file — drop any Flutter imports (split if needed; pure parts only). Update package-prefixed imports to the new package.

- [ ] **Step T3.3.x.3**: Add `export 'src/<file>.dart';` to `live_edit_models/lib/live_edit_models.dart`.

- [ ] **Step T3.3.x.4**: In the original location, replace the file's content with a single re-export:

```dart
export 'package:live_edit_models/live_edit_models.dart' show <SymbolList>;
```

- [ ] **Step T3.3.x.5**: Run code generation if needed:

```bash
cd flutter_live_edit/live_edit_models && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step T3.3.x.6**: Verify both packages still build:

```bash
cd flutter_live_edit/live_edit_models && dart analyze
cd flutter_live_edit/flutter_live_edit_toolkit && flutter analyze
cd flutter_live_edit/live_edit_tooling_ui_kit && flutter analyze
```

- [ ] **Step T3.3.x.7**: Commit each file's migration individually with message `refactor(live_edit_models): migrate <SymbolList> to shared package`.

Repeat for every file in the inventory. **Apply the same 7-step pattern to each** — do not batch.

### T3.4: Make `flutter_live_edit_toolkit` and `live_edit_tooling_ui_kit` depend on `live_edit_models`

**Files:**
- Modify: `flutter_live_edit/flutter_live_edit_toolkit/pubspec.yaml`
- Modify: `flutter_live_edit/live_edit_tooling_ui_kit/pubspec.yaml`

- [ ] **Step T3.4.1: Add path dep to flutter_live_edit_toolkit**

```yaml
  live_edit_models:
    path: ../live_edit_models
```

- [ ] **Step T3.4.2: Add path dep to live_edit_tooling_ui_kit**

Same yaml edit.

- [ ] **Step T3.4.3: Resolve and run tests**

```bash
cd flutter_live_edit/flutter_live_edit_toolkit && flutter pub get && flutter test
cd flutter_live_edit/live_edit_tooling_ui_kit && flutter pub get && flutter test
```
Expected: all tests pass.

- [ ] **Step T3.4.4: Round-trip serialization tests in live_edit_models**

For every model that has `fromJson`/`toJson`, write a round-trip test:

```dart
// flutter_live_edit/live_edit_models/test/serialization_test.dart
import 'package:live_edit_models/live_edit_models.dart';
import 'package:test/test.dart';

void main() {
  group('LiveEditCommand serialization', () {
    test('LiveEditStartSessionCommand round-trips', () {
      const original = LiveEditStartSessionCommand(/* … realistic fixture … */);
      final json = original.toJson();
      final decoded = LiveEditStartSessionCommand.fromJson(json);
      expect(decoded, original);
    });
    // Add one test per command type from the inventory.
  });
}
```

- [ ] **Step T3.4.5: Run live_edit_models tests**

```bash
cd flutter_live_edit/live_edit_models && dart test
```
Expected: all serialization tests pass.

- [ ] **Step T3.4.6: Commit**

```bash
git add flutter_live_edit/flutter_live_edit_toolkit/pubspec.yaml \
  flutter_live_edit/live_edit_tooling_ui_kit/pubspec.yaml \
  flutter_live_edit/live_edit_models/test
git commit -m "refactor(live_edit): consume shared live_edit_models package"
```

### T3.5: Update `mcp_server_dart` to depend on `live_edit_models` (preparatory)

**Files:**
- Modify: `mcp_server_dart/pubspec.yaml`
- Modify: `mcp_server_dart/lib/src/capabilities/live_edit/live_edit_command_executor.dart` (imports only)

- [ ] **Step T3.5.1: Add path dep**

```yaml
  live_edit_models:
    path: ../flutter_live_edit/live_edit_models
```

- [ ] **Step T3.5.2: Replace imports in live_edit_command_executor.dart**

Change:
```dart
import 'package:flutter_live_edit_toolkit/src/models/live_edit_models.dart';
import 'package:live_edit_tooling_ui_kit/src/models/models.dart';
```

To:
```dart
import 'package:live_edit_models/live_edit_models.dart';
```

(Apply the same to any other server file with these imports.)

- [ ] **Step T3.5.3: Run server tests**

```bash
cd mcp_server_dart && flutter test
```
Expected: all tests still pass — behavior unchanged, dep tree narrowed.

- [ ] **Step T3.5.4: Verify Flutter is gone from server's transitive deps**

Run:
```bash
cd mcp_server_dart && dart pub deps --json | grep -i flutter
```
Expected: still shows `flutter_live_edit_toolkit` and `live_edit_tooling_ui_kit` in deps (until T5 removes them) — but the server's *direct* model dependency is now `live_edit_models` only. Full Flutter removal happens in T5.

- [ ] **Step T3.5.5: Verify the `uses-material-design` warnings**

Run:
```bash
cd mcp_server_dart && flutter test 2>&1 | grep -c "uses-material-design"
```
Expected: count drops compared to before T3 (warnings come from `live_edit_tooling_ui_kit` Flutter deps; not fully resolved until T5).

- [ ] **Step T3.5.6: Delete the migration inventory checklist**

```bash
rm flutter_live_edit/live_edit_models/MIGRATION_INVENTORY.md
```

- [ ] **Step T3.5.7: Commit**

```bash
git add mcp_server_dart flutter_live_edit/live_edit_models
git commit -m "refactor(server): consume live_edit_models for shared types"
```

### T3.6: End-of-T3 checkpoint

- [ ] **Step T3.6.1: All four packages green**

```bash
cd flutter_live_edit/live_edit_models && dart test
cd flutter_live_edit/flutter_live_edit_toolkit && flutter test
cd flutter_live_edit/live_edit_tooling_ui_kit && flutter test
cd mcp_server_dart && flutter test
```

- [ ] **Step T3.6.2: User checkpoint**

"T3 done. Ready to start T4 (mcp_capability_core)?"

---

## Task T4: `mcp_capability_core` package

Extract the static Playwright-parity + inspection tools out of `mcp_server_dart/lib/src/capabilities/{dart,error_analysis,visual_capture,diagnostics}/` and `mcp_toolkit/.../toolkits/*.dart` registrations exposed by the server, into a peer Dart package. **The toolkit-side runtime in `mcp_toolkit/.../toolkits/` stays where it is; only the server-side wrapper that exposes those tools as MCP tools moves.**

### T4.1: Tool inventory

- [ ] **Step T4.1.1: List server-exposed core tool names**

Run:
```bash
grep -rn "name: ['\"]" mcp_server_dart/lib/src/capabilities/ --include="*.dart" \
  | grep -v "live_edit\|dynamic_registry"
```

Capture all tool names. Cross-reference against `interaction_toolkit.dart`, `flutter_mcp_toolkit.dart`, `flutter_permission_toolkit.dart`. Confirmed tool list from spec: `app_errors`, `view_screenshots`, `view_details`, `inspect_widget_at_point`, `semantic_snapshot`, `tap_widget`, `enter_text`, `scroll`, `long_press`, `swipe`, `drag`, `get_recent_logs`, `wait_for`, `press_key`, `handle_dialog`, `navigate`, `fill_form`, `hover`, plus permission toolkit tools and any inspector-specific tools (`hot_reload_flutter`, `connect_debug_app`, `discover_debug_apps`, `get_vm`, `get_extension_rpcs`, `capture_ui_snapshot`, debug dump tools).

Save to `todo/_t4_tool_inventory.txt` (deleted at end of T4).

### T4.2: Scaffold the package

**Files:**
- Create: `mcp_capability_core/pubspec.yaml`
- Create: `mcp_capability_core/analysis_options.yaml`
- Create: `mcp_capability_core/lib/mcp_capability_core.dart`
- Create: `mcp_capability_core/lib/src/core_capability.dart`

- [ ] **Step T4.2.1: pubspec.yaml**

```yaml
name: mcp_capability_core
description: >-
  Core MCP capability — Playwright-parity interaction tools, inspection,
  diagnostics, hot-reload coordination. Server-side glue only; depends on
  no Flutter packages.
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.11.0

dependencies:
  dart_mcp: ^0.5.0
  mcp_capability_kernel:
    path: ../mcp_capability_kernel
  vm_service: ^15.0.2
  meta: ^1.17.0
  collection: ^1.19.1
  from_json_to_json: ^0.5.0

dev_dependencies:
  test: ^1.25.0
  lints: ^6.1.0
```

- [ ] **Step T4.2.2: analysis_options.yaml** — copy from `mcp_server_dart/analysis_options.yaml`.

- [ ] **Step T4.2.3: Barrel**

```dart
// mcp_capability_core/lib/mcp_capability_core.dart
library mcp_capability_core;

export 'src/core_capability.dart' show CoreCapability;
```

- [ ] **Step T4.2.4: Skeleton CoreCapability**

```dart
// mcp_capability_core/lib/src/core_capability.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

final class CoreCapability implements Capability {
  const CoreCapability();

  @override
  String get id => 'core';

  @override
  String get description =>
      'Core Flutter inspector — interaction, inspection, hot reload, diagnostics.';

  @override
  String get version => '3.0.0';

  @override
  Future<void> register(final CapabilityContext context) async {
    // Tool groups added in T4.3+.
  }

  @override
  Future<void> dispose() async {}
}
```

- [ ] **Step T4.2.5: pub get**

```bash
cd mcp_capability_core && dart pub get
```

- [ ] **Step T4.2.6: Commit**

```bash
git add mcp_capability_core
git commit -m "feat(capability_core): scaffold package with empty CoreCapability"
```

### T4.3: Migrate one tool as the worked example

To establish the pattern, migrate `tap_widget` end-to-end. The same pattern applies to every other tool in the inventory.

**Files:**
- Create: `mcp_capability_core/lib/src/tools/interaction_tools.dart`
- Create: `mcp_capability_core/test/tools/interaction_tools_test.dart`
- Modify: `mcp_capability_core/lib/src/core_capability.dart`

- [ ] **Step T4.3.1: Read the existing tap_widget registration in mcp_server_dart**

Run:
```bash
grep -rn "tap_widget" mcp_server_dart/lib/ --include="*.dart"
```

Locate where the schema, description, and dispatch handler are defined. Capture all three.

- [ ] **Step T4.3.2: Write the failing test**

```dart
// mcp_capability_core/test/tools/interaction_tools_test.dart
import 'package:mcp_capability_core/src/tools/interaction_tools.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:test/test.dart';

import '../_test_helpers.dart';

void main() {
  group('interaction tools', () {
    test('registers tap_widget under the core_ prefix', () async {
      final ctx = FakeCapabilityContext(capabilityId: 'core');
      registerInteractionTools(ctx);

      expect(
        ctx.registeredToolNames,
        contains('tap_widget'),
        reason:
            'capability registers BARE name; kernel/host applies prefix '
            'only at the host boundary',
      );
    });

    test('tap_widget schema has expected required fields', () async {
      final ctx = FakeCapabilityContext(capabilityId: 'core');
      registerInteractionTools(ctx);
      final reg = ctx.registrationFor('tap_widget');
      expect(reg, isNotNull);
      expect(
        reg!.inputSchema['required'],
        containsAll(<String>[/* fields read from existing handler */]),
      );
    });
  });
}
```

- [ ] **Step T4.3.3: Write the FakeCapabilityContext helper**

```dart
// mcp_capability_core/test/_test_helpers.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

final class FakeCapabilityContext implements CapabilityContext {
  FakeCapabilityContext({required this.capabilityId});

  @override
  final String capabilityId;

  final Map<String, ToolRegistration> _tools = <String, ToolRegistration>{};

  Iterable<String> get registeredToolNames => _tools.keys;
  ToolRegistration? registrationFor(final String name) => _tools[name];

  @override
  CapabilityConfig get config => const CapabilityConfig();

  @override
  void registerTool(final ToolRegistration registration) {
    _tools[registration.name] = registration;
  }

  @override
  void registerResource(final ResourceRegistration registration) {
    throw UnimplementedError();
  }

  @override
  T require<T extends HostService>() {
    throw HostServiceUnavailableError('FakeCapabilityContext: $T');
  }

  @override
  void log(final String message, {final LogLevel level = LogLevel.info}) {}
}
```

- [ ] **Step T4.3.4: Run test, verify failure**

```bash
cd mcp_capability_core && dart test test/tools/interaction_tools_test.dart
```
Expected: FAIL on missing `interaction_tools.dart`.

- [ ] **Step T4.3.5: Implement `registerInteractionTools` for tap_widget only**

```dart
// mcp_capability_core/lib/src/tools/interaction_tools.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

void registerInteractionTools(final CapabilityContext ctx) {
  ctx.registerTool(
    ToolRegistration(
      name: 'tap_widget',
      description: '<copy from existing server registration>',
      inputSchema: <String, Object?>{
        // copy verbatim from the existing server handler's schema
      },
      handler: (request) async {
        // Move the existing handler body here. Replace any direct VM
        // service calls with `ctx.require<VmServiceClient>().callServiceExtension(...)`.
        // — but we don't have ctx in handler scope (handler is created at
        // registration time). Capture services into closures inside
        // registerInteractionTools.
        throw UnimplementedError('handler body — see step T4.3.6');
      },
    ),
  );
}
```

- [ ] **Step T4.3.6: Capture host services in closure**

The handler needs the `VmServiceClient` (and possibly other services). Restructure:

```dart
void registerInteractionTools(final CapabilityContext ctx) {
  final vmService = ctx.require<VmServiceClient>();

  ctx.registerTool(
    ToolRegistration(
      name: 'tap_widget',
      description: '...',
      inputSchema: const <String, Object?>{ /* schema */ },
      handler: (request) async {
        // Use vmService.callServiceExtension(...) to drive the original
        // mcp_toolkit extension that handles tap_widget. Translate
        // the extension's response into a CallToolResult.
        final result = await vmService.callServiceExtension(
          'ext.mcp.toolkit.tap_widget',
          args: request.arguments?.cast<String, Object?>(),
        );
        // ... shape result into CallToolResult per existing handler
      },
    ),
  );
}
```

For the test to pass, only the registration needs to succeed — the handler body can be filled in iteratively. The test in T4.3.2 covers registration shape; **a separate handler-level test must be added** that calls the handler with a mock VmServiceClient.

- [ ] **Step T4.3.7: Wire CoreCapability to call the registration**

```dart
// mcp_capability_core/lib/src/core_capability.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

import 'tools/interaction_tools.dart';

final class CoreCapability implements Capability {
  const CoreCapability();

  @override
  String get id => 'core';
  @override
  String get description =>
      'Core Flutter inspector — interaction, inspection, hot reload, diagnostics.';
  @override
  String get version => '3.0.0';

  @override
  Future<void> register(final CapabilityContext context) async {
    registerInteractionTools(context);
  }

  @override
  Future<void> dispose() async {}
}
```

- [ ] **Step T4.3.8: Run tests, verify pass**

```bash
cd mcp_capability_core && dart test
```
Expected: green.

- [ ] **Step T4.3.9: Commit**

```bash
git add mcp_capability_core
git commit -m "feat(capability_core): migrate tap_widget as the pattern reference"
```

### T4.4: Migrate every remaining tool

Apply the T4.3.1 → T4.3.9 pattern to each tool in the inventory. Group by file:

- [ ] **T4.4.a — interaction_tools.dart**: `enter_text`, `scroll`, `long_press`, `swipe`, `drag`, `hover`, `press_key`. Each gets its own test.
- [ ] **T4.4.b — inspection_tools.dart**: `view_screenshots`, `view_details`, `inspect_widget_at_point`, `app_errors`, `capture_ui_snapshot`. Each gets its own test.
- [ ] **T4.4.c — wait_tools.dart**: `wait_for` (with all four predicates: text, noText, stable, time). Each predicate gets a test.
- [ ] **T4.4.d — navigation_tools.dart**: `handle_dialog`, `navigate`. Each gets its own test.
- [ ] **T4.4.e — form_tools.dart**: `fill_form`. With its specific fail-on-first-error behavior preserved.
- [ ] **T4.4.f — log_tools.dart**: `get_recent_logs`. Single test.
- [ ] **T4.4.g — semantic_tools.dart**: `semantic_snapshot`. Test covers the DPR fix.
- [ ] **T4.4.h — permission_tools.dart**: every permission toolkit tool from `mcp_toolkit/.../toolkits/flutter_permission_toolkit.dart`.
- [ ] **T4.4.i — flutter_inspector_tools.dart**: `hot_reload_flutter`, `connect_debug_app`, `discover_debug_apps`, `get_vm`, `get_extension_rpcs`. These need a `HotReloadCoordinator` + raw VM service access.
- [ ] **T4.4.j — debug_dump_tools.dart**: `debug_dump_layer_tree`, `debug_dump_semantics_tree`, `debug_dump_render_tree`, `debug_dump_focus_tree`. Gated on `configuration.dumpsSupported`.

Each sub-task t4.4.x: write tests first, run, fail, implement, run, pass, commit. Per-tool commit messages: `feat(capability_core): migrate <tool_name>`.

- [ ] **Step T4.4.z: Final sub-task — register every tool group from CoreCapability**

```dart
@override
Future<void> register(final CapabilityContext context) async {
  registerInteractionTools(context);
  registerInspectionTools(context);
  registerWaitTools(context);
  registerNavigationTools(context);
  registerFormTools(context);
  registerLogTools(context);
  registerSemanticTools(context);
  registerPermissionTools(context);
  registerFlutterInspectorTools(context);
  if (context.config.getBool('dumps_supported', defaultValue: false)) {
    registerDebugDumpTools(context);
  }
}
```

### T4.5: Wire CoreCapability into server's main.dart behind the flag

**Files:**
- Modify: `mcp_server_dart/pubspec.yaml`
- Modify: `mcp_server_dart/bin/main.dart`

- [ ] **Step T4.5.1: Add path dep**

```yaml
  mcp_capability_core:
    path: ../mcp_capability_core
```

- [ ] **Step T4.5.2: Register inside main.dart when flag is on**

```dart
// inside main.dart, after McpHost is constructed:
if (config.useCapabilityKernel) {
  await host.registerCapability(const CoreCapability());
}
```

The host needs to be constructed *with* `services` containing concrete `VmServiceClient`, `HotReloadCoordinator`, and (later) `DynamicRegistryBridge` instances. Build adapters:

```dart
// mcp_server_dart/lib/src/mcp_toolkit_server/host_services_impl.dart  (NEW)
final class _VmServiceClientAdapter implements VmServiceClient {
  // delegate to whatever the existing VMServiceSupport mixin uses
}
final class _HotReloadCoordinatorAdapter implements HotReloadCoordinator {
  // delegate to existing hot reload code
}
```

(Concrete adapter bodies depend on existing internal APIs; read `VMServiceSupport` mixin and trace.)

- [ ] **Step T4.5.3: End-to-end smoke test with flag on**

Test: start the server with `--use-capability-kernel`, call `tools/list`, assert `core_tap_widget` appears.

```dart
// mcp_server_dart/test/capability_kernel_smoke_test.dart
// Use existing test infra; mirror p1_commands_test.dart's setup pattern.
```

- [ ] **Step T4.5.4: Run tests, verify pass**

```bash
cd mcp_server_dart && flutter test
```

- [ ] **Step T4.5.5: Delete the inventory checklist**

```bash
rm todo/_t4_tool_inventory.txt
```

- [ ] **Step T4.5.6: Commit**

```bash
git add mcp_server_dart
git commit -m "feat(server): wire CoreCapability behind --use-capability-kernel flag"
```

### T4.6: End-of-T4 checkpoint

- [ ] **Step T4.6.1: Both packages green**

```bash
cd mcp_capability_core && dart test
cd mcp_server_dart && flutter test
```

- [ ] **Step T4.6.2: User checkpoint**

"T4 done. Ready for T5 (mcp_capability_live_edit)?"

---

## Task T5: `mcp_capability_live_edit` package

Extract `mcp_server_dart/lib/src/capabilities/live_edit/` into its own package. Trim `LiveEditCommandExecutor` to only the commands that genuinely need the server (verified body-by-body during this task — spec table is provisional). Move `LiveEditAgentService` from `flutter_live_edit_toolkit/lib/src/ai/agent/` to here, since it is server-side orchestration.

### T5.1: Verify command classification by reading bodies

The spec lists ~10 commands; the actual executor has ~24 (T0/T2 reading found `LiveEditSetEditMode`, `LiveEditUpdateDraft`, `LiveEditGetDraft`, `LiveEditDiscardDraft`, `LiveEditEndSession`, `LiveEditListAgentBackends`, `LiveEditGetAgentBackend`, `LiveEditSetAgentBackend`, `LiveEditResolveDraft`, `LiveEditApplyDraft`, `LiveEditAcceptResolution`, `LiveEditRejectResolution`, `LiveEditGetPreviewState` beyond the spec list). All need re-classifying.

- [ ] **Step T5.1.1: Read each command handler in `live_edit_command_executor.dart`**

For each `_liveEdit*` method, identify whether it:
- (a) only reaches into the host (VM service, hot reload, agent service) — **server-side**.
- (b) only proxies to a client tool via `_host.runClientTool(...)` — **app-side dynamic**.
- (c) does both — **server-side** (the orchestration is the value-add).

- [ ] **Step T5.1.2: Save classification to a worksheet**

Save to `todo/_t5_command_classification.md` (deleted at end of T5):

```markdown
| Command | Body summary | Class |
|---|---|---|
| StartSession | hot reload + agent setup | server |
| PrepareSession | hot reload + VM service prep | server |
| ListAgentBackends | reads in-process registry | server |
| GetAgentBackend | reads in-process registry | server |
| SetAgentBackend | mutates in-process registry | server |
| ResolveDraft | invokes Codex/Cursor | server |
| ApplyDraft | code generation pipeline | server |
| AcceptResolution | hot reload + commit | server |
| RejectResolution | rollback | server |
| SetOverlay | proxies to client | dynamic |
| GetTree | proxies to client | dynamic |
| SelectAtPoint | proxies to client | dynamic |
| GetSelection | proxies to client | dynamic |
| GetCapabilities | proxies to client | dynamic |
| GetSelectionCandidates | proxies to client | dynamic |
| SetActiveSelection | proxies to client | dynamic |
| GetPropertyPanel | proxies to client | dynamic |
| SetEditMode | proxies to client | dynamic |
| GetPreviewState | proxies to client | dynamic |
| UpdateDraft | proxies to client | dynamic |
| GetDraft | proxies to client | dynamic |
| DiscardDraft | proxies to client | dynamic |
| EndSession | client signal + server cleanup | server |
```

This is a draft; T5.1.1 may reclassify cells.

### T5.2: Scaffold the package

**Files:**
- Create: `mcp_capability_live_edit/pubspec.yaml`
- Create: `mcp_capability_live_edit/analysis_options.yaml`
- Create: `mcp_capability_live_edit/lib/mcp_capability_live_edit.dart`
- Create: `mcp_capability_live_edit/lib/src/live_edit_capability.dart`

- [ ] **Step T5.2.1: pubspec.yaml**

```yaml
name: mcp_capability_live_edit
description: >-
  Live-edit MCP capability — server-side orchestration for hot-reload-driven
  code generation. App-side tools (selection, panel, tree introspection) are
  registered from flutter_live_edit_toolkit via the dynamic registry.
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.11.0

dependencies:
  dart_mcp: ^0.5.0
  mcp_capability_kernel:
    path: ../mcp_capability_kernel
  live_edit_models:
    path: ../flutter_live_edit/live_edit_models
  vm_service: ^15.0.2
  meta: ^1.17.0
  collection: ^1.19.1
  from_json_to_json: ^0.5.0
  xsoulspace_inference_codex_exec: ^0.1.0-beta.1
  xsoulspace_inference_core: ^0.1.0-beta.1
  xsoulspace_inference_cursor_agent: ^0.1.0-beta.1

dev_dependencies:
  test: ^1.25.0
  lints: ^6.1.0
```

- [ ] **Step T5.2.2: Skeleton LiveEditCapability**

```dart
// mcp_capability_live_edit/lib/src/live_edit_capability.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

final class LiveEditCapability implements Capability {
  const LiveEditCapability();

  @override
  String get id => 'live_edit';

  @override
  String get description =>
      'Live edit — overlay-driven code generation with hot reload integration.';

  @override
  String get version => '3.0.0';

  @override
  Future<void> register(final CapabilityContext context) async {
    // Claim the live_edit namespace on the dynamic registry bridge so
    // app-side dynamic registrations get the correct prefix.
    context.require<DynamicRegistryBridge>().claim(namespace: 'live_edit');
    // Static tools registered in T5.4.
  }

  @override
  Future<void> dispose() async {}
}
```

- [ ] **Step T5.2.3: Barrel + pub get + commit**

```dart
// mcp_capability_live_edit/lib/mcp_capability_live_edit.dart
library mcp_capability_live_edit;

export 'src/live_edit_capability.dart' show LiveEditCapability;
```

```bash
cd mcp_capability_live_edit && dart pub get
git add mcp_capability_live_edit
git commit -m "feat(capability_live_edit): scaffold package with empty LiveEditCapability"
```

### T5.3: Move host bindings + executor + agent service

**Files:**
- Move: `mcp_server_dart/lib/src/capabilities/live_edit/live_edit_host_bindings.dart` → `mcp_capability_live_edit/lib/src/live_edit_host_bindings.dart`
- Move: `mcp_server_dart/lib/src/capabilities/live_edit/live_edit_command_executor.dart` → `mcp_capability_live_edit/lib/src/live_edit_command_executor.dart`
- Move: `flutter_live_edit/flutter_live_edit_toolkit/lib/src/ai/agent/live_edit_agent_service.dart` → `mcp_capability_live_edit/lib/src/agent/live_edit_agent_service.dart`
- Move: `mcp_server_dart/test/<live_edit_*>_test.dart` → `mcp_capability_live_edit/test/`

For each file:
- [ ] **Step T5.3.x.1**: `git mv` the file. Update its imports (some `package:flutter_inspector_mcp_server/...` imports become internal to `mcp_capability_live_edit`).
- [ ] **Step T5.3.x.2**: Verify the moved file compiles inside its new package: `dart analyze`.
- [ ] **Step T5.3.x.3**: Commit individually: `refactor(live_edit): move <file> to mcp_capability_live_edit`.

### T5.4: Trim the executor to server-only commands

**Files:**
- Modify: `mcp_capability_live_edit/lib/src/live_edit_command_executor.dart`

- [ ] **Step T5.4.1: Delete switch arms for app-side commands**

Remove from the `execute()` switch every command marked "dynamic" in T5.1.2's classification. Delete the corresponding `_liveEdit*` private methods.

- [ ] **Step T5.4.2: Replace executor entry point**

Replace the public `execute(command)` method with a narrower API surface — one Dart method per server-side command type, called directly by the new MCP tools registered in T5.5. Goal: stop using `LiveEditCommand` as the dispatch surface; commands become method calls.

```dart
// rough shape after the trim
final class LiveEditCommandExecutor {
  LiveEditCommandExecutor({
    required final LiveEditHostBindings host,
    final LiveEditAgentService? agentService,
  }) : _host = host,
       _agent = agentService ?? LiveEditAgentService();

  final LiveEditHostBindings _host;
  final LiveEditAgentService _agent;

  Future<CoreResult> startSession(final LiveEditStartSessionCommand c) { ... }
  Future<CoreResult> prepareSession(final LiveEditPrepareSessionCommand c) { ... }
  Future<CoreResult> endSession(final LiveEditEndSessionCommand c) { ... }
  Future<CoreResult> resolveDraft(final LiveEditResolveDraftCommand c) { ... }
  Future<CoreResult> applyDraft(final LiveEditApplyDraftCommand c) { ... }
  Future<CoreResult> acceptResolution(final LiveEditAcceptResolutionCommand c) { ... }
  Future<CoreResult> rejectResolution(final LiveEditRejectResolutionCommand c) { ... }
  Future<CoreResult> listAgentBackends() { ... }
  Future<CoreResult> getAgentBackend(final LiveEditGetAgentBackendCommand c) { ... }
  Future<CoreResult> setAgentBackend(final LiveEditSetAgentBackendCommand c) { ... }
}
```

(Method names and exact set follow from T5.1.2.)

- [ ] **Step T5.4.3: Update any callers — none should remain**

Run:
```bash
grep -rn "LiveEditCommand\b\|executor.execute(" mcp_server_dart/ mcp_capability_live_edit/ --include="*.dart"
```

If anything outside the executor still references `LiveEditCommand` polymorphically for app-side commands, update.

- [ ] **Step T5.4.4: Run executor tests**

```bash
cd mcp_capability_live_edit && dart test
```
Expected: green for the surviving server-side commands; deleted commands' tests deleted.

- [ ] **Step T5.4.5: Commit**

```bash
git add mcp_capability_live_edit
git commit -m "refactor(live_edit): trim executor to server-side commands only"
```

### T5.5: Register server-side commands as MCP tools

**Files:**
- Create: `mcp_capability_live_edit/lib/src/tools/session_tools.dart`
- Create: `mcp_capability_live_edit/lib/src/tools/draft_tools.dart`
- Create: `mcp_capability_live_edit/lib/src/tools/agent_backend_tools.dart`
- Modify: `mcp_capability_live_edit/lib/src/live_edit_capability.dart`

For each surviving command:

- [ ] **T5.5.x.1**: Write the failing test that asserts the bare tool name is registered.
- [ ] **T5.5.x.2**: Implement the registration in the corresponding tools file. Handler delegates to `LiveEditCommandExecutor`'s typed method.
- [ ] **T5.5.x.3**: Update `LiveEditCapability.register()` to call the registration function.
- [ ] **T5.5.x.4**: Run test, verify pass.
- [ ] **T5.5.x.5**: Commit per command: `feat(live_edit): register start_session as static tool`, etc.

Bare tool names (kernel will prefix): `start_session`, `prepare_session`, `end_session`, `resolve_draft`, `apply_draft`, `accept_resolution`, `reject_resolution`, `list_agent_backends`, `get_agent_backend`, `set_agent_backend`. Final exposed names: `live_edit_start_session`, etc.

### T5.6: Wire LiveEditCapability into server's main.dart behind the flag

**Files:**
- Modify: `mcp_server_dart/pubspec.yaml`
- Modify: `mcp_server_dart/bin/main.dart`

- [ ] **Step T5.6.1: Add path dep**

```yaml
  mcp_capability_live_edit:
    path: ../mcp_capability_live_edit
```

- [ ] **Step T5.6.2: Drop dependencies on flutter_live_edit_toolkit and live_edit_tooling_ui_kit**

Remove from `mcp_server_dart/pubspec.yaml`. The server should now have **zero Flutter package dependencies**.

- [ ] **Step T5.6.3: Register LiveEditCapability**

```dart
// mcp_server_dart/bin/main.dart
if (config.useCapabilityKernel) {
  await host.registerCapability(const CoreCapability());
  await host.registerCapability(const LiveEditCapability());
}
```

- [ ] **Step T5.6.4: Implement DynamicRegistryBridge service in the server**

`mcp_capability_live_edit.LiveEditCapability.register()` calls `context.require<DynamicRegistryBridge>().claim(namespace: 'live_edit')`. The server must provide a concrete implementation in its `services` map.

```dart
// mcp_server_dart/lib/src/mcp_toolkit_server/dynamic_registry_bridge_impl.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

import 'mixins/dynamic_registry_integration.dart';

final class DynamicRegistryBridgeImpl implements DynamicRegistryBridge {
  DynamicRegistryBridgeImpl(this._dynamicRegistry);

  final DynamicRegistryIntegration _dynamicRegistry;
  final Set<String> _claimedNamespaces = <String>{};

  @override
  void claim({required final String namespace}) {
    if (_claimedNamespaces.contains(namespace)) {
      throw StateError('Namespace "$namespace" already claimed.');
    }
    _claimedNamespaces.add(namespace);
    _dynamicRegistry.registerNamespaceClaim(namespace);
  }
}
```

The legacy `DynamicRegistryIntegration` mixin will need a new method `registerNamespaceClaim(String)` to support prefix application during dynamic-tool dispatch. Plumb through.

- [ ] **Step T5.6.5: Verify server has zero Flutter package deps**

```bash
cd mcp_server_dart && dart pub deps --json | python3 -c "
import json, sys
deps = json.load(sys.stdin)
for pkg in deps['packages']:
    if 'flutter' in pkg['name'].lower() and pkg['kind'] in ('direct', 'transitive'):
        print(pkg['name'])
"
```
Expected: empty output (modulo `flutter_test` if dev_dep — that's fine).

- [ ] **Step T5.6.6: Run server tests with flag on**

```bash
cd mcp_server_dart && flutter test --dart-define=USE_CAPABILITY_KERNEL=true
```

(The test suite needs a way to set the flag; if `USE_CAPABILITY_KERNEL` env var is not how the flag flows through tests, use whatever harness already exists — read `flutter_inspector_mcp_server/test/test_helpers.dart` if present.)

Expected: green.

- [ ] **Step T5.6.7: Run with flag off (the legacy path) — also still green**

```bash
cd mcp_server_dart && flutter test
```
Expected: green. This validates the legacy path still works for the next two phases.

- [ ] **Step T5.6.8: Delete the worksheet**

```bash
rm todo/_t5_command_classification.md
```

- [ ] **Step T5.6.9: Commit**

```bash
git add mcp_server_dart mcp_capability_live_edit
git commit -m "feat(server): drop Flutter deps; wire LiveEditCapability + DynamicRegistryBridge"
```

### T5.7: End-of-T5 checkpoint

- [ ] **Step T5.7.1: Server is Flutter-free**

```bash
grep -E "flutter_live_edit_toolkit|live_edit_tooling_ui_kit" mcp_server_dart/pubspec.yaml
```
Expected: no matches in `dependencies:` block (only in `dev_dependencies:` if present, which is also fine to remove).

- [ ] **Step T5.7.2: User checkpoint**

"T5 complete. Server has zero Flutter deps. Ready for T6 (MCPToolkitBinding.initialize(capabilityId))?"

---

## Task T6: Extend `MCPToolkitBinding` to tag dynamic registrations

**Files:**
- Modify: `mcp_toolkit/mcp_toolkit/lib/src/mcp_toolkit_binding.dart`
- Modify: `mcp_toolkit/mcp_toolkit/lib/src/mcp_toolkit_binding_base.dart`
- Modify: `mcp_toolkit/mcp_toolkit/lib/src/mcp_models.dart`
- Create: `mcp_toolkit/mcp_toolkit/test/binding_capability_id_test.dart`

### T6.1: Write failing test for capabilityId support

- [ ] **Step T6.1.1: Test**

```dart
// mcp_toolkit/mcp_toolkit/test/binding_capability_id_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  setUp(() {
    // reset singleton between tests if helper exists
  });

  test('initialize accepts a capabilityId; default is null', () {
    final binding = MCPToolkitBinding.instance;
    binding.initialize(capabilityId: 'live_edit');
    expect(binding.capabilityId, 'live_edit');
  });

  test('addEntries tags entries with the configured capabilityId', () async {
    MCPToolkitBinding.instance.initialize(capabilityId: 'live_edit');
    final entry = MCPCallEntry.tool(
      handler: (request) => MCPCallResult(message: 'ok', parameters: const {}),
      definition: MCPToolDefinition(
        name: 'select',
        description: 'select a widget',
        inputSchema: const {'type': 'object'},
      ),
    );
    await MCPToolkitBinding.instance.addEntries(entries: {entry});

    final stored =
        MCPToolkitBinding.instance.allEntries.firstWhere((e) => e.key == entry.key);
    expect(stored.capabilityId, 'live_edit');
  });

  test('initialize without capabilityId tags entries with null (legacy)', () async {
    MCPToolkitBinding.instance.initialize();
    final entry = MCPCallEntry.tool(
      handler: (request) => MCPCallResult(message: 'ok', parameters: const {}),
      definition: MCPToolDefinition(
        name: 'custom',
        description: 'd',
        inputSchema: const {'type': 'object'},
      ),
    );
    await MCPToolkitBinding.instance.addEntries(entries: {entry});

    final stored =
        MCPToolkitBinding.instance.allEntries.firstWhere((e) => e.key == entry.key);
    expect(stored.capabilityId, isNull);
  });
}
```

- [ ] **Step T6.1.2: Run, verify failure**

```bash
cd mcp_toolkit/mcp_toolkit && flutter test test/binding_capability_id_test.dart
```
Expected: FAIL — `capabilityId` getter / param doesn't exist.

### T6.2: Implement capabilityId on the binding

- [ ] **Step T6.2.1: Extend MCPCallEntry**

In `mcp_toolkit/mcp_toolkit/lib/src/mcp_models.dart`, add:
```dart
final String? capabilityId;
```
Add it to constructors with a default of `null`. Plumb through `copyWith`.

- [ ] **Step T6.2.2: Extend `MCPToolkitBinding.initialize`**

```dart
@override
void initialize({
  final String serviceExtensionName = kMCPServiceExtensionName,
  final int maxErrors = kDefaultMaxErrors,
  final String? capabilityId,   // NEW
}) {
  _capabilityId = capabilityId;
  // existing body
  super.initialize(serviceExtensionName: serviceExtensionName);
}

String? _capabilityId;
String? get capabilityId => _capabilityId;
```

- [ ] **Step T6.2.3: Tag entries in addEntries**

```dart
Future<void> addEntries({required final Set<MCPCallEntry> entries}) async {
  final tagged = _capabilityId == null
      ? entries
      : entries
          .map((e) => e.copyWith(capabilityId: _capabilityId))
          .toSet();
  assert(() {
    initializeServiceExtensions(errorMonitor: this, entries: tagged);
    return true;
  }());
}
```

- [ ] **Step T6.2.4: Plumb capabilityId through the DTD/service-extension boundary**

The current `initializeServiceExtensions` registers a service extension per entry. Extend the JSON encoding of registered tool metadata to include `capabilityId` so the server-side dynamic registry sees it.

(Concrete change depends on `mcp_toolkit_binding_base.dart` and `mcp_toolkit_extensions.dart` internals — read both, identify the encoding point, add the field.)

- [ ] **Step T6.2.5: Run test, verify pass**

```bash
cd mcp_toolkit/mcp_toolkit && flutter test test/binding_capability_id_test.dart
```
Expected: green.

- [ ] **Step T6.2.6: Commit**

```bash
git add mcp_toolkit/mcp_toolkit
git commit -m "feat(toolkit): MCPToolkitBinding.initialize(capabilityId) + tag dynamic entries"
```

### T6.3: Wire DynamicRegistryBridge to consume the tag

**Files:**
- Modify: `mcp_server_dart/lib/src/mcp_toolkit_server/mixins/dynamic_registry_integration.dart`

- [ ] **Step T6.3.1: Read incoming entry's capabilityId and apply prefix**

When a dynamic entry arrives via DTD, check its `capabilityId`:
- If null → legacy path, name unchanged (legacy behavior preserved).
- If non-null → must match a claimed namespace. Apply `<capabilityId>_` prefix to the name. If the namespace is unclaimed, reject with `tool_name_collision` error envelope (kernel rule).

```dart
// pseudocode in dynamic_registry_integration.dart
String resolvedToolName(final dynamic entry) {
  final capId = entry.capabilityId as String?;
  if (capId == null) return entry.name;
  if (!_claimedNamespaces.contains(capId)) {
    throw McpError(
      code: 'tool_name_collision',
      message:
          'Dynamic entry tagged with unclaimed capability "$capId".',
    );
  }
  return '${capId}_${entry.name}';
}
```

- [ ] **Step T6.3.2: Add server-side test**

```dart
// mcp_server_dart/test/dynamic_registry_namespace_test.dart
test('dynamic entry tagged live_edit gets live_edit_ prefix in tools/list', () async {
  // 1. Register LiveEditCapability (which claims 'live_edit')
  // 2. Inject a fake DTD-style entry with capabilityId='live_edit', name='select'
  // 3. Assert tools/list contains 'live_edit_select'
});

test('dynamic entry tagged with unclaimed namespace is rejected', () async {
  // 1. No capability claims 'unknown_ns'
  // 2. Inject entry with capabilityId='unknown_ns'
  // 3. Assert tool_name_collision error
});

test('dynamic entry with no capabilityId surfaces with legacy unprefixed name', () async {
  // legacy compat — for now, before T8 cut
});
```

- [ ] **Step T6.3.3: Run tests**

```bash
cd mcp_server_dart && flutter test test/dynamic_registry_namespace_test.dart
```
Expected: green.

- [ ] **Step T6.3.4: Commit**

```bash
git add mcp_server_dart
git commit -m "feat(server): apply capability prefix to tagged dynamic entries"
```

### T6.4: End-of-T6 checkpoint

- [ ] **Step T6.4.1: All toolkit tests pass**

```bash
cd mcp_toolkit/mcp_toolkit && flutter test
```

- [ ] **Step T6.4.2: All server tests pass**

```bash
cd mcp_server_dart && flutter test
```

- [ ] **Step T6.4.3: User checkpoint**

"T6 done. Ready for T7 (flutter_live_edit_toolkit adoption)?"

---

## Task T7: `flutter_live_edit_toolkit` adopts capabilityId + registers app-side commands

**Files:**
- Modify: `flutter_live_edit/flutter_live_edit_toolkit/lib/live_edit_runtime.dart`
- Modify: `flutter_live_edit/flutter_live_edit_toolkit/lib/src/mcp_toolkit_tools/live_edit_tool_layer_glue.dart`
- Modify: `flutter_live_edit/flutter_live_edit_toolkit/test/` (multiple files)

### T7.1: Initialize binding with capability id

- [ ] **Step T7.1.1: Update live_edit_runtime.dart**

Find the bootstrap call (likely in `live_edit_runtime.dart` or wherever live-edit is initialized in the host app). Update to:

```dart
MCPToolkitBinding.instance.initialize(capabilityId: 'live_edit');
```

- [ ] **Step T7.1.2: Test**

```dart
// flutter_live_edit/flutter_live_edit_toolkit/test/runtime_init_test.dart
test('LiveEditRuntime initializes binding with live_edit capabilityId', () {
  // call LiveEditRuntime bootstrap, then:
  expect(MCPToolkitBinding.instance.capabilityId, 'live_edit');
});
```

- [ ] **Step T7.1.3: Run, verify pass**

```bash
cd flutter_live_edit/flutter_live_edit_toolkit && flutter test test/runtime_init_test.dart
```

- [ ] **Step T7.1.4: Commit**

```bash
git add flutter_live_edit/flutter_live_edit_toolkit
git commit -m "feat(live_edit): initialize binding with capabilityId='live_edit'"
```

### T7.2: Register app-side dynamic commands

For each command classified as "dynamic" in T5.1.2, add a registration in `live_edit_tool_layer_glue.dart`. The handlers move from server-side `_liveEdit*` methods (which were deleted in T5.4) to app-side `MCPCallEntry` handlers.

For each dynamic command:

- [ ] **T7.2.x.1**: Write a test asserting that after `LiveEditToolLayerGlue.register()`, an entry with name e.g. `set_overlay` and capabilityId `live_edit` exists in `MCPToolkitBinding.instance.allEntries`.
- [ ] **T7.2.x.2**: Run, verify failure.
- [ ] **T7.2.x.3**: Add the registration. Handler implementation is the body of the method previously deleted from `LiveEditCommandExecutor` in T5.4 — but adapted to run app-side (no `host.runClientTool` indirection; direct access to overlay state, selection model, etc.).
- [ ] **T7.2.x.4**: Run, verify pass.
- [ ] **T7.2.x.5**: Commit per command: `feat(live_edit): register set_overlay as dynamic tool`.

Bare names: `set_overlay`, `get_tree`, `select_at_point`, `get_selection`, `get_capabilities`, `get_selection_candidates`, `set_active_selection`, `get_property_panel`, `set_edit_mode`, `get_preview_state`, `update_draft`, `get_draft`, `discard_draft`. (Final names will be `live_edit_set_overlay` etc. after server-side prefixing.)

### T7.3: End-to-end with flag on

- [ ] **Step T7.3.1: Showcase smoke test**

Run:
```bash
cd flutter_test_app && flutter run --dart-define=USE_CAPABILITY_KERNEL=true -d macos
```

(In a separate terminal, run the MCP inspector against the server with `--use-capability-kernel`.)

Expected: tool names appear with `core_` and `live_edit_` prefixes. Calls succeed.

- [ ] **Step T7.3.2: Maestro flow against prefixed names**

If Maestro flows reference tool names: update one flow to use prefixed names and assert it passes; leave others unchanged for T8.

- [ ] **Step T7.3.3: Commit**

```bash
git add flutter_live_edit/flutter_live_edit_toolkit
git commit -m "feat(live_edit): register all 13 dynamic commands via MCPToolkitBinding"
```

### T7.4: End-of-T7 checkpoint

- [ ] **Step T7.4.1: All packages green**

```bash
cd mcp_capability_kernel && dart test
cd mcp_capability_core && dart test
cd mcp_capability_live_edit && dart test
cd flutter_live_edit/live_edit_models && dart test
cd flutter_live_edit/flutter_live_edit_toolkit && flutter test
cd flutter_live_edit/live_edit_tooling_ui_kit && flutter test
cd mcp_toolkit/mcp_toolkit && flutter test
cd mcp_server_dart && flutter test
```

- [ ] **Step T7.4.2: User checkpoint**

"T7 complete. Both code paths work side-by-side. Ready for T8 (the cut)?"

This is the last reversible checkpoint. After T8 begins, old tool names are gone.

---

## Task T8: Flip the flag default to ON — the cut

**Files:**
- Modify: `mcp_server_dart/bin/main.dart`
- Modify: `flutter_live_edit/flutter_live_edit_toolkit/lib/live_edit_runtime.dart` (if it conditioned on the flag)
- Modify: All Maestro flows referencing old names

This is the only irreversible step. After it lands, old tool names return `tool_not_found`.

### T8.1: Flip the flag

- [ ] **Step T8.1.1: Change default in mcp_server_dart**

Edit `bin/main.dart`:

```dart
parser.addFlag(
  'use-capability-kernel',
  defaultsTo: true,  // was false
  help: 'Route tool registrations through mcp_capability_kernel.',
);
```

- [ ] **Step T8.1.2: Run full server test suite**

```bash
cd mcp_server_dart && flutter test
```
Expected: green. Failing tests indicate something still relies on the legacy path; those tests must be updated to use prefixed names.

- [ ] **Step T8.1.3: Update Maestro flows to use prefixed names**

```bash
grep -rn "tap_widget\|enter_text\|wait_for\|fill_form\|hover\|press_key\|handle_dialog\|navigate\|live_edit\..*[a-z]" maestro/ --include="*.yaml"
```

For each match: update to `core_<name>` (Playwright tools) or `live_edit_<name>` (live-edit dynamic tools). Keep one negative test that calls the **old** name `tap_widget` and asserts `tool_not_found` — that's the cut codified.

- [ ] **Step T8.1.4: Run Maestro flows**

```bash
make showcase  # in one terminal
# in another: run the relevant maestro flow
```
Expected: flows pass with new names; the negative test gets `tool_not_found`.

- [ ] **Step T8.1.5: Commit**

```bash
git add mcp_server_dart maestro/
git commit -m "feat(release): flip --use-capability-kernel default to on; update flows"
```

### T8.2: User-facing acknowledgement

- [ ] **Step T8.2.1: Surface the cut to the user**

After T8.1.5 lands: "T8 complete. Tool names are now prefixed. Old names return `tool_not_found`. Ready to delete the legacy path (T9)?"

---

## Task T9: Delete the legacy registration path

**Files:**
- Modify: `mcp_server_dart/bin/main.dart` — remove the flag
- Modify: `mcp_server_dart/lib/src/mcp_toolkit_server/server.dart` — remove the legacy branch
- Delete: `mcp_server_dart/lib/src/capabilities/` (everything under, except possibly `dynamic_registry/` which stays as host machinery)

### T9.1: Delete the flag

- [ ] **Step T9.1.1: Remove the flag definition + branching**

In `bin/main.dart`:
- Delete the `parser.addFlag('use-capability-kernel', ...)` line.
- Delete any `if (config.useCapabilityKernel)` branches; keep only the kernel-path body.
- Remove `useCapabilityKernel` from the configuration type.

- [ ] **Step T9.1.2: Delete server.dart legacy branch**

In `lib/src/mcp_toolkit_server/server.dart`: remove the `if (configuration.useCapabilityKernel)` branch. Only the kernel path remains.

- [ ] **Step T9.1.3: Run tests**

```bash
cd mcp_server_dart && flutter test
```
Expected: green.

### T9.2: Delete dead code under `lib/src/capabilities/`

- [ ] **Step T9.2.1: Identify what's safe to delete**

```bash
ls mcp_server_dart/lib/src/capabilities/
```

Of the directories `dart/`, `error_analysis/`, `visual_capture/`, `diagnostics/`, `dynamic_registry/`, `live_edit/`:

- `live_edit/` was already moved in T5.3. If anything remains, delete.
- `dynamic_registry/` is host machinery — KEEP.
- `dart/`, `error_analysis/`, `visual_capture/`, `diagnostics/` — these had their tool definitions migrated to `mcp_capability_core` in T4.4. Delete the now-unused tool registrations. Anything that's not a tool (helpers, services consumed by host) — KEEP.

For each directory: read remaining files, delete dead ones.

- [ ] **Step T9.2.2: Run tests after each delete**

```bash
cd mcp_server_dart && flutter test
```

- [ ] **Step T9.2.3: Commit per directory**

```bash
git add mcp_server_dart/lib/src/capabilities/<dir>
git commit -m "chore(server): remove migrated <dir> capability glue"
```

### T9.3: End-of-T9 checkpoint

- [ ] **Step T9.3.1: All tests green, no dead code**

```bash
cd mcp_server_dart && flutter analyze && flutter test
```

- [ ] **Step T9.3.2: User checkpoint**

"T9 done. Legacy path deleted. Ready for T10 (docs + contracts)?"

---

## Task T10: Docs + contracts

**Files:**
- Modify: `tool/contracts/check_plugin_surfaces.sh`
- Create: `tool/contracts/expected_tool_surface.txt`
- Modify: `docs/MCP_RPC_DESCRIPTION.md` (regenerated)
- Modify: `CHANGELOG.md`
- Modify: `ARCHITECTURE.md` (capability composition section)

### T10.1: Tool-surface snapshot contract

- [ ] **Step T10.1.1: Generate expected surface**

The contract needs a deterministic snapshot of every MCP tool the default server exposes. Add a CLI subcommand to produce it:

```dart
// mcp_server_dart/bin/flutter_mcp_cli.dart  (extend existing CLI)
// Add: flutter_mcp_cli list-tools
//   - Constructs an McpHost
//   - Registers CoreCapability() and LiveEditCapability()
//   - Iterates host.toolNames sorted
//   - Prints one name per line to stdout
```

Then generate the snapshot:

```bash
cd mcp_server_dart && make compile
./build/flutter_mcp_cli list-tools | sort > ../tool/contracts/expected_tool_surface.txt
```

The first run writes the file; subsequent contract checks diff against it. Updates to the surface (adding a tool, etc.) are deliberate snapshot regenerations reviewed in PR.

- [ ] **Step T10.1.2: Update check_plugin_surfaces.sh**

Make the contract diff actual `tools/list` output against `expected_tool_surface.txt`. Failure mode: diff output + instruction to update the snapshot intentionally.

- [ ] **Step T10.1.3: Run check-contracts**

```bash
make check-contracts
```
Expected: all four checks pass.

- [ ] **Step T10.1.4: Commit**

```bash
git add tool/contracts CHANGELOG.md
git commit -m "feat(contracts): tool-surface snapshot contract for capability-composed names"
```

### T10.2: CHANGELOG + docs

- [ ] **Step T10.2.1: Add v3.0.0 CHANGELOG entry**

Include:
- Summary of capability inversion architecture
- Full table of renamed tools (old → new) — generated by mapping `core_<name>` for everything in the spec's migration set, `live_edit_<name>` for live-edit tools
- Migration guidance for users (restart MCP client; tool names rediscovered automatically; user-authored prompts referencing old names need update)

- [ ] **Step T10.2.2: Regenerate MCP_RPC_DESCRIPTION.md**

If there's a generator script (`tool/release/...`), run it. Otherwise update by hand against `tools/list` output.

- [ ] **Step T10.2.3: Update ARCHITECTURE.md**

Add a "Capability Composition" section under "Architecture Components". Mention:
- The kernel package
- Per-capability packages
- How to write a custom binary
- The reserved `app_` namespace

- [ ] **Step T10.2.4: Commit**

```bash
git add CHANGELOG.md docs/MCP_RPC_DESCRIPTION.md ARCHITECTURE.md
git commit -m "docs(release): document capability inversion + tool rename for v3.0.0"
```

### T10.3: Acceptance verification

The spec's acceptance criteria:

- [ ] `mcp_server_dart/pubspec.yaml` has no Flutter package dependencies. **Check:** `grep -E "flutter_live_edit|flutter:|live_edit_tooling_ui_kit" mcp_server_dart/pubspec.yaml | grep -v "^\s*flutter_test:"` → no matches.
- [ ] `make check-contracts` passes. **Check:** `make check-contracts` → exit 0.
- [ ] Maestro flows pass with new tool names. **Check:** `make showcase` + run flows.
- [ ] A custom-binary example exists. **Check:** scaffold `examples/custom_mcp_server/` with a `main.dart` that registers only `CoreCapability()` (no live-edit). It builds and lists only `core_*` tools.
- [ ] CHANGELOG documents the rename. **Check:** read `CHANGELOG.md`.
- [ ] No `uses-material-design` warnings in `mcp_server_dart` test runs. **Check:** `cd mcp_server_dart && flutter test 2>&1 | grep -c "uses-material-design"` → 0.

### T10.4: Final checkpoint

- [ ] **Step T10.4.1: All criteria met**

Run the six checks above. Surface results to user.

- [ ] **Step T10.4.2: User signoff**

"T10 done. All acceptance criteria met. v3.0.0 ready to tag?"

- [ ] **Step T10.4.3: Tag (only after explicit user approval)**

```bash
git tag v3.0.0
# user pushes when ready
```

---

## Risk register

| Risk | Mitigation | Detected by |
|---|---|---|
| `dart_mcp ^0.5.0` rejects underscore-heavy tool names | Verify in T1.3 by registering and listing a `core_tap_widget` against a real client | T2.3 smoke test |
| Adapter for `VmServiceClient` doesn't capture all internal call sites | Read `VMServiceSupport` mixin during T4.5; one adapter per public method | T4.6 test suite |
| Live-edit dynamic commands need server-side state we missed | T5.1 reads each handler body; if surprised, reclassify and stay server-side | T5.7 user checkpoint |
| `freezed` codegen hits stale state during model migration | Run `build_runner build --delete-conflicting-outputs` after every move | T3.3 per-file analyze |
| Test harness can't easily set `--use-capability-kernel` flag | Add a test-only constructor on the configuration that takes the flag directly | T2.3.4 smoke |
| Hot reload across capability boundaries breaks during dev | The kernel's `register()` is called once at startup; not at hot reload time. App-side `MCPToolkitBinding` continues to handle hot reload as before | manual showcase |

---

## Self-review (run after writing the plan)

**Spec coverage check:**
- ✅ Goal 1 (no Flutter in server): T3 + T5
- ✅ Goal 2 (per-capability packages): T1, T4, T5
- ✅ Goal 3 (thin shells): T2, T4.5, T5.6, T9
- ✅ Goal 4 (kernel-enforced prefix): T1.3, T2.2, T6.3
- ✅ Goal 5 (hard cut at v3.0.0): T8

**Placeholder scan:**
- One unavoidable category: handler bodies in T4.4 reference "the existing handler body" rather than copy the full code. This is intentional — full inline copies of ~25 handlers would balloon the plan past usefulness; reading the existing source is the trustworthy operation. Sub-tasks call out the exact files to read.
- T6.2.4 ("plumb capabilityId through the DTD/service-extension boundary") is the only step that's underspecified — it requires tracing two files (`mcp_toolkit_binding_base.dart` and `mcp_toolkit_extensions.dart`) before knowing the exact edit. Acceptable: the test in T6.1 fully constrains correctness.

**Type consistency check:**
- `Capability`, `CapabilityContext`, `ToolRegistration` used identically T1 → T7.
- `DynamicRegistryBridge.claim(namespace:)` used in T1, T5, T6 with same signature.
- `applyPrefix(capabilityId:, name:)` used in T1, T2 with same signature.

**Scope check:** 10 task groups, ~80 total sub-tasks. Big but bounded; each task group has its own user checkpoint. No task group depends on a sibling once started; T0 and T3 are explicitly carve-outs for parallel agents.
