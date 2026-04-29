# P2: fill_form + hover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land two Playwright-parity MCP tools — `fill_form` (batch text entry) and `hover` (mouse hover) — completing P2 of the Playwright-parity roadmap.

**Architecture:** `fill_form` is pure server-side orchestration: `_fillForm` loops over `command.fields` and calls the existing `_enterText` executor per field; no new toolkit code. `hover` adds one method on `GestureInteractionService` that synthesizes a `PointerHoverEvent` at the widget's center via the existing `GestureBinding.handlePointerEvent` path (tier-2 pointer-event infrastructure). Both follow the established 7-place registration pattern; no new app-binding APIs needed.

**Tech Stack:** Dart, Flutter (`GestureBinding.handlePointerEvent`, `PointerHoverEvent`, `MouseRegion`, `flutter_test`), the project's `CoreCommandExecutor` + `CommandSpec` registry. Reference plans: `docs/superpowers/plans/2026-04-27-wait-for.md` (P0) and `docs/superpowers/plans/2026-04-27-p1-keyboard-dialog-navigate.md` (P1).

---

## Scope adjustment from the roadmap

The roadmap's P2 listed **three** tools: `fill_form`, `select_option`, `hover`. **`select_option` is dropped** for the same reason `handle_dialog accept` was dropped from P1: post-`wait_for`, the equivalent flow `tap_widget(dropdown) → wait_for(text='option') → tap_widget(item)` is three tool calls, but `wait_for` already returns the snapshot in its payload — so `select_option` would save zero round-trips while adding Flutter-version-specific dropdown logic that breaks for `DropdownMenu` vs. `DropdownButton` vs. custom popup pickers.

Roadmap audit doc gets the note: "select_option deferred — expressible as `tap_widget → wait_for(text=label) → tap_widget` post-P0; revisit if usage data shows the wrapper is worth the surface area."

This brings P2 from 3 tools / 6 tasks to 2 tools / 5 tasks — back to the "small batch" the roadmap originally promised.

---

## Decisions locked in

1. **`fill_form` orchestration site.** Server-side loop in `_fillForm`. Each field calls the existing `_enterText` executor (which itself does `_ensureVmConnected` + `callFlutterExtension('ext.mcp.toolkit.enter_text', ...)`). Reuses tested code; no new wire format. Connection check happens once per `_enterText` call but the fast-path is cheap (already-connected returns immediately) — not worth refactoring.
2. **`fill_form` failure semantics.** Stop on first failure. Return `{success: bool, results: [perFieldResult], failedAt: int?, failedRef: String?}`. Don't continue past a failure — partial form is worse than a clean error pointing at the bad field.
3. **`fill_form` snapshot staleness.** Optional `snapshotId` for the whole batch; if the *first* field's `enter_text` returns `stale_snapshot`, the whole batch fails with that error. Don't re-validate per field.
4. **`hover` mouse-tracker priming.** `MouseTracker` computes `MouseRegion.onEnter`/`onExit` from *position changes*. A single `PointerHoverEvent` at the target may not trigger `onEnter` if the tracker's last-known position is already over the widget (or unset, depending on framework state). The implementation **fires a priming hover at `Offset(-100, -100)` first**, then the target hover. Reuses `pointer: 1` for both events so the tracker treats them as the same logical mouse.
5. **`hover` pointer-event API.** Uses the existing tier-2 `GestureBinding.instance.handlePointerEvent` path (same as `_dispatchTap` etc. in `gesture_interaction_service.dart`). New static `hoverAtRef(ref)` method on `GestureInteractionService`. No semantic-action equivalent for hover, so no tier-1.
6. **No new app-binding API.** Unlike P1's `setNavigatorKey`, neither `fill_form` nor `hover` requires app-side opt-in.
7. **Test pattern.** Both tools use `testWidgets` with the act-then-pump pattern (no parallel-pump needed — neither tool awaits user-time delays internally). The hover test asserts a `MouseRegion.onEnter` callback fired.
8. **Wire format.** Server `_fillForm` does *not* call an extension RPC — it loops `_enterText` directly. So no toolkit-side `OnFillFormEntry` and no `mcpToolkitExtKeys.fillForm` constant. Server `_hover` does call `mcpToolkitExtKeys.hover` with `{ref}` (string, no encoding needed).

---

## File structure

### Create
- `mcp_server_dart/test/p2_commands_test.dart` — regression-guard for both new catalog build paths.
- (No new toolkit service file — `hover` lives on the existing `GestureInteractionService`.)

### Modify
- `mcp_toolkit/mcp_toolkit/lib/src/services/gesture_interaction_service.dart` — add `hoverAtRef(ref)` method.
- `mcp_toolkit/mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart` — add `OnHoverEntry` and register in `getInteractionToolkitEntries()`. **No** `OnFillFormEntry` (server-side only).
- `mcp_toolkit/mcp_toolkit/test/control_flow_service_test.dart` — append `hover` widget tests. (Reuses the existing test file since it already imports the right deps; alternatively could create a new file — pick whichever feels cleaner during implementation, no behavior difference.)
- `mcp_server_dart/lib/src/mcp_toolkit_consts.dart` — add `hover` to all three records. **No** `fillForm`.
- `mcp_server_dart/lib/src/shared_core/commands/visual_widget_commands.dart` — add `FillFormCommand`, `HoverCommand`.
- `mcp_server_dart/lib/src/shared_core/commands/commands_specs.dart` — two `CommandSpec` entries.
- `mcp_server_dart/lib/src/shared_core/types/error_codes.dart` — add `fillFormFailed`, `hoverFailed`.
- `mcp_server_dart/lib/src/shared_core/command_executor.dart` — two new dispatch arms + `_fillForm` (server-side loop) + `_hover` (extension-RPC wrapper).
- `mcp_server_dart/lib/src/mcp_toolkit_server/handlers/interaction_handler.dart` — two `Tool` definitions + two handler methods.
- `mcp_server_dart/lib/src/mcp_toolkit_server/mixins/flutter_inspector.dart` — two `registerTool` calls.
- `mcp_server_dart/test/command_catalog_test.dart` — extend with one new test.

---

## Task 1: Server-side scaffolding for both tools

Mirror Task 1 of the wait_for and P1 plans. Add command classes, error codes, the `hover` extension constant (no `fillForm` constant — server-side only), command specs, and dispatch stubs.

**Files:**
- Modify: `mcp_server_dart/lib/src/shared_core/types/error_codes.dart`
- Modify: `mcp_server_dart/lib/src/shared_core/commands/visual_widget_commands.dart`
- Modify: `mcp_server_dart/lib/src/shared_core/commands/commands_specs.dart`
- Modify: `mcp_server_dart/lib/src/mcp_toolkit_consts.dart`
- Modify: `mcp_server_dart/lib/src/shared_core/command_executor.dart` (stub cases)
- Modify: `mcp_server_dart/test/command_catalog_test.dart`

- [ ] **Step 1: Write failing test**

Append inside the existing `group('CommandCatalog', () { ... })` block in `mcp_server_dart/test/command_catalog_test.dart`:

```dart
    test('fill_form, hover commands are registered', () {
      for (final name in ['fill_form', 'hover']) {
        final spec = catalog.specFor(name);
        expect(spec, isNotNull, reason: '$name spec missing');
        expect(spec!.mcpExposed, isTrue, reason: '$name not mcpExposed');
      }

      final ff = catalog.buildCommand('fill_form', {
        'fields': <Map<String, Object?>>[
          {'ref': 's_0', 'text': 'alice'},
          {'ref': 's_1', 'text': 'bob'},
        ],
      }) as FillFormCommand;
      expect(ff.fields, hasLength(2));
      expect(ff.fields.first['ref'], 's_0');
      expect(ff.fields.first['text'], 'alice');

      final hv = catalog.buildCommand('hover', {
        'ref': 's_3',
      }) as HoverCommand;
      expect(hv.ref, 's_3');
    });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_server_dart && \
  flutter test test/command_catalog_test.dart > /tmp/p2_t1a.log 2>&1
echo "exit=$?"; tail -15 /tmp/p2_t1a.log
```
Expected: FAIL — `FillFormCommand` and `HoverCommand` undefined.

- [ ] **Step 3: Add command classes**

Append to `mcp_server_dart/lib/src/shared_core/commands/visual_widget_commands.dart` after the last P1 command (`NavigateCommand`):

```dart
final class FillFormCommand extends CoreCommand {
  const FillFormCommand({required this.fields, this.snapshotId});

  /// Each field is `{ref: String, text: String}`. Stop on first failure.
  final List<Map<String, Object?>> fields;
  final int? snapshotId;

  @override
  String get name => 'fill_form';
}

final class HoverCommand extends CoreCommand {
  const HoverCommand({required this.ref, this.snapshotId});

  final String ref;
  final int? snapshotId;

  @override
  String get name => 'hover';
}
```

- [ ] **Step 4: Add error codes**

In `mcp_server_dart/lib/src/shared_core/types/error_codes.dart`, after `navigatorNotRegistered` (around line 108):

```dart
  static const fillFormFailed = 'fill_form_failed';
  static const hoverFailed = 'hover_failed';
```

In the same file, append to `_descriptorMap` after `navigatorNotRegistered`'s entry:

```dart
      CoreErrorCode.fillFormFailed: CoreErrorDescriptor(
        code: CoreErrorCode.fillFormFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.hoverFailed: CoreErrorDescriptor(
        code: CoreErrorCode.hoverFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
```

- [ ] **Step 5: Add the `hover` extension constant**

In `mcp_server_dart/lib/src/mcp_toolkit_consts.dart`, append `hover` to all three records (mirror exactly how `pressKey` was added in P1):

```dart
// mcpToolkitExtKeys (record literal):
  hover: '$mcpToolkitExt.${mcpToolkitExtNames.hover}',

// allMcpToolkitExtNames (set):
  mcpToolkitExtNames.hover,

// mcpToolkitExtNames (record literal):
  hover: 'hover',
```

**Do not** add a `fillForm` constant — the server-side loop reuses `enter_text`'s extension key, no new RPC name needed.

- [ ] **Step 6: Add CommandSpec entries**

In `mcp_server_dart/lib/src/shared_core/commands/commands_specs.dart`, after the `navigate` spec, insert:

```dart
      CommandSpec(
        name: 'fill_form',
        description:
            'Batch text entry: enters text into multiple fields in one '
            'tool call. Stops on first failure (partial form is worse '
            'than a clean error). Each field requires a fresh ref from '
            'semantic_snapshot. Optional snapshotId is checked against '
            'the first field only — refs that change mid-batch will '
            'surface as a stale_snapshot error from the per-field '
            'enter_text dispatch.',
        inputSchema: _objectSchema(
          required: const ['fields'],
          properties: {
            'fields': const <String, Object?>{
              'type': 'array',
              'items': <String, Object?>{
                'type': 'object',
                'required': <String>['ref', 'text'],
                'properties': <String, Object?>{
                  'ref': <String, Object?>{'type': 'string'},
                  'text': <String, Object?>{'type': 'string'},
                },
              },
            },
            'snapshotId': _intSchema(),
          },
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) {
          final raw = args['fields'];
          final list = raw is List
              ? raw
                  .whereType<Object?>()
                  .map<Map<String, Object?>>((final e) {
                    if (e is Map<String, Object?>) return e;
                    if (e is Map) return e.cast<String, Object?>();
                    return const <String, Object?>{};
                  })
                  .toList(growable: false)
              : const <Map<String, Object?>>[];
          final snapshotIdRaw = _intArg(args, 'snapshotId', fallback: 0);
          return FillFormCommand(
            fields: list,
            snapshotId: snapshotIdRaw == 0 ? null : snapshotIdRaw,
          );
        },
      ),
      CommandSpec(
        name: 'hover',
        description:
            'Synthesize a mouse hover at the centre of a widget identified '
            'by a semantic snapshot ref. Drives MouseRegion.onEnter/onExit '
            'and listeners on PointerHoverEvent. Requires a desktop or web '
            'host (mobile platforms have no hover concept). '
            'Call semantic_snapshot immediately before to get fresh refs. '
            'Pass snapshot_id to detect staleness.',
        inputSchema: _objectSchema(
          required: const ['ref'],
          properties: {
            'ref': _stringSchema(),
            'snapshotId': _intSchema(),
          },
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) {
          final snapshotIdRaw = _intArg(args, 'snapshotId', fallback: 0);
          return HoverCommand(
            ref: _stringArg(args, 'ref', fallback: ''),
            snapshotId: snapshotIdRaw == 0 ? null : snapshotIdRaw,
          );
        },
      ),
```

If `_stringSchema` or `_intSchema` shapes are different from what's shown, follow the file's existing convention — check sibling specs (e.g. `wait_for` and `press_key`) for a working reference.

- [ ] **Step 7: Add dispatch stubs**

In `command_executor.dart`'s `_dispatch` switch, after the `NavigateCommand()` arm, append:

```dart
      FillFormCommand() => Future.value(
        CoreResult.failure(
          code: CoreErrorCode.fillFormFailed,
          message: 'fill_form is registered but not yet implemented',
        ),
      ),
      HoverCommand() => Future.value(
        CoreResult.failure(
          code: CoreErrorCode.hoverFailed,
          message: 'hover is registered but not yet implemented',
        ),
      ),
```

- [ ] **Step 8: Run test to verify it passes**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_server_dart && \
  flutter test test/command_catalog_test.dart > /tmp/p2_t1b.log 2>&1
echo "exit=$?"; tail -10 /tmp/p2_t1b.log
```
Expected: PASS — all 19 tests green (18 pre-existing + 1 new).

- [ ] **Step 9: Commit (from repo root)**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter && \
  git add mcp_server_dart/lib/src/shared_core/types/error_codes.dart \
          mcp_server_dart/lib/src/shared_core/commands/visual_widget_commands.dart \
          mcp_server_dart/lib/src/shared_core/commands/commands_specs.dart \
          mcp_server_dart/lib/src/mcp_toolkit_consts.dart \
          mcp_server_dart/lib/src/shared_core/command_executor.dart \
          mcp_server_dart/test/command_catalog_test.dart && \
  git commit -m "feat(p2): scaffold fill_form and hover commands

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `hover` toolkit method + MCP entry

**Files:**
- Modify: `mcp_toolkit/mcp_toolkit/lib/src/services/gesture_interaction_service.dart` — add `hoverAtRef`
- Modify: `mcp_toolkit/mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart` — add `OnHoverEntry` + register
- Modify: `mcp_toolkit/mcp_toolkit/test/control_flow_service_test.dart` — append hover tests

- [ ] **Step 1: Write failing tests**

Append to `mcp_toolkit/mcp_toolkit/test/control_flow_service_test.dart`, before the closing `}` of `void main()`:

```dart
  // -----------------------------------------------------------------------
  // hover
  // -----------------------------------------------------------------------

  testWidgets('hover triggers MouseRegion.onEnter on the targeted widget',
      (final tester) async {
    var entered = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Semantics(
            label: 'hover_target',
            child: MouseRegion(
              onEnter: (_) => entered = true,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Take a snapshot so resolveCenter has the ref's center.
    final snapshot = await SemanticSnapshotService.buildSemanticSnapshot();
    final nodes = snapshot['nodes']! as List<Object?>;
    // Find the ref whose label is 'hover_target'.
    final targetEntry = nodes.firstWhere(
      (final n) =>
          (n is Map && (n['label'] as String?)?.contains('hover_target') == true),
    ) as Map<Object?, Object?>;
    final ref = targetEntry['ref']! as String;

    final result = await GestureInteractionService.hoverAtRef(ref);
    await tester.pump();

    expect(result['success'], isTrue);
    expect(entered, isTrue);
  });

  testWidgets('hover returns ref_not_found for an unknown ref',
      (final tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pumpAndSettle();

    final result = await GestureInteractionService.hoverAtRef('s_does_not_exist');
    expect(result['success'], isFalse);
    expect(result['error'], 'ref_not_found');
  });
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_toolkit/mcp_toolkit && \
  flutter test test/control_flow_service_test.dart --plain-name "hover" \
  > /tmp/p2_t2a.log 2>&1
echo "exit=$?"; tail -15 /tmp/p2_t2a.log
```
Expected: FAIL — `hoverAtRef` undefined.

- [ ] **Step 3: Add `hoverAtRef` to `GestureInteractionService`**

In `mcp_toolkit/mcp_toolkit/lib/src/services/gesture_interaction_service.dart`, find the `_dispatchDrag` method (around line 580) and append a new public method just before it (or near the other public `*AtRef` methods — pick the location that matches the file's existing structure; tap/enter/scroll/swipe/drag/longPress are public, the `_dispatch*` are private).

```dart
  /// Synthesize a mouse hover at the centre of the widget identified by
  /// [ref]. Drives `MouseRegion.onEnter`/`onExit` via the framework's
  /// mouse tracker (which computes enter/exit transitions from position
  /// changes).
  ///
  /// Primes the tracker with an off-screen hover first so the target hover
  /// is unambiguously a position change — without priming, a single hover
  /// at the target may not produce an enter transition if the tracker's
  /// last-known position is unset or already over the target.
  static Future<Map<String, Object?>> hoverAtRef(final String ref) async {
    final node = SemanticSnapshotService.resolveRef(ref);
    if (node == null) {
      return _refNotFound(ref);
    }
    final centre = SemanticSnapshotService.resolveCenter(ref);
    if (centre == null) {
      return _refNotFound(ref);
    }

    final binding = GestureBinding.instance;
    // Prime: hover off-screen first so the target hover is a clean
    // position change. Reuses pointer id so the mouse tracker treats
    // them as the same logical mouse.
    const pointer = 1;
    binding.handlePointerEvent(
      PointerHoverEvent(
        pointer: pointer,
        position: const ui.Offset(-100, -100),
        kind: PointerDeviceKind.mouse,
        timeStamp: _now(),
      ),
    );
    binding.handlePointerEvent(
      PointerHoverEvent(
        pointer: pointer,
        position: centre,
        kind: PointerDeviceKind.mouse,
        timeStamp: _now(),
      ),
    );
    await _waitFrame();

    return <String, Object?>{
      'success': true,
      'ref': ref,
      'position': <String, Object?>{
        'dx': centre.dx,
        'dy': centre.dy,
      },
    };
  }
```

If `_refNotFound`, `_now`, or `_waitFrame` helpers aren't visible at this scope, search the file for their definitions — they're already used by `tapAtRef` etc. and should be in-class.

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_toolkit/mcp_toolkit && \
  flutter test test/control_flow_service_test.dart > /tmp/p2_t2b.log 2>&1
echo "exit=$?"; tail -15 /tmp/p2_t2b.log
```
Expected: all hover tests PASS, plus all P1/wait_for tests still green.

If the `MouseRegion.onEnter` test fails (`entered` stays false): the priming offset (`Offset(-100, -100)`) may be inside the visible widget tree under a multi-view or unusual layout. Try `Offset(-1000, -1000)` or assert `tester.binding.window.physicalSize` first. Don't drop the priming step — without it the test is unreliable across binding states.

- [ ] **Step 5: Add the MCP entry**

In `mcp_toolkit/mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart`, append `OnHoverEntry()` to `getInteractionToolkitEntries()` (after `OnNavigateEntry()`).

Append the extension type at the bottom of the file (after `OnNavigateEntry`):

```dart
// ---------------------------------------------------------------------------
// Hover
// ---------------------------------------------------------------------------

/// {@template on_hover_entry}
/// Synthesize a mouse hover at the centre of a widget identified by ref.
/// Drives MouseRegion.onEnter/onExit. Requires a desktop or web host
/// (mobile platforms have no hover concept).
/// {@endtemplate}
extension type OnHoverEntry._(MCPCallEntry entry) implements MCPCallEntry {
  /// {@macro on_hover_entry}
  factory OnHoverEntry() {
    final entry = MCPCallEntry.tool(
      handler: (final parameters) async {
        final ref = jsonDecodeString(parameters['ref']);
        if (ref.isEmpty) {
          return MCPCallResult(
            message: 'Missing required parameter "ref".',
            parameters: const <String, Object?>{
              'success': false,
              'error': 'missing_ref',
            },
          );
        }
        final snapshotIdRaw = jsonDecodeInt(parameters['snapshotId']);
        final snapshotId = snapshotIdRaw == 0 ? null : snapshotIdRaw;
        if (snapshotId != null &&
            snapshotId != SemanticSnapshotService.currentSnapshotId) {
          return MCPCallResult(
            message:
                'Snapshot is stale. Call semantic_snapshot to get fresh refs.',
            parameters: <String, Object?>{
              'ok': false,
              'error': 'stale_snapshot',
              'providedSnapshotId': snapshotId,
              'currentSnapshotId': SemanticSnapshotService.currentSnapshotId,
            },
          );
        }
        final result = await GestureInteractionService.hoverAtRef(ref);
        return MCPCallResult(
          message: result['success'] == true
              ? 'Hovered widget at ref "$ref".'
              : 'hover failed: ${result['error']}.',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'hover',
        description:
            'Synthesize a mouse hover at the centre of a widget identified '
            'by a semantic ref. Drives MouseRegion.onEnter/onExit and '
            'listeners on PointerHoverEvent. Desktop/web only — mobile '
            'has no hover concept. Call semantic_snapshot immediately '
            'before to get fresh refs.',
        inputSchema: ObjectSchema(
          required: const ['ref'],
          properties: {
            'ref': StringSchema(),
            'snapshotId': IntegerSchema(),
          },
        ),
      ),
    );
    return OnHoverEntry._(entry);
  }
}
```

- [ ] **Step 6: Run full toolkit tests**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_toolkit/mcp_toolkit && \
  flutter test > /tmp/p2_t2c.log 2>&1
echo "exit=$?"; tail -25 /tmp/p2_t2c.log
```
Expected: all package tests pass. Bootstrap test should report 18 registered tools (was 17 after P1).

- [ ] **Step 7: Commit**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter && \
  git add mcp_toolkit/mcp_toolkit/lib/src/services/gesture_interaction_service.dart \
          mcp_toolkit/mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart \
          mcp_toolkit/mcp_toolkit/test/control_flow_service_test.dart && \
  git commit -m "feat(p2): hover tool via PointerHoverEvent

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Server-side wiring for both tools

Replace the Task-1 dispatch stubs with real executors, add `Tool` definitions and handlers in `interaction_handler.dart`, register both in `flutter_inspector.dart`. Mirrors Task 7 of the wait_for plan and Task 6 of the P1 plan.

**Files:**
- Modify: `mcp_server_dart/lib/src/shared_core/command_executor.dart`
- Modify: `mcp_server_dart/lib/src/mcp_toolkit_server/handlers/interaction_handler.dart`
- Modify: `mcp_server_dart/lib/src/mcp_toolkit_server/mixins/flutter_inspector.dart`
- Create: `mcp_server_dart/test/p2_commands_test.dart`

- [ ] **Step 1: Write the regression-guard tests**

Create `mcp_server_dart/test/p2_commands_test.dart`:

```dart
import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  final catalog = CommandCatalog.instance;

  group('FillFormCommand', () {
    test('round-trips fields and snapshotId', () {
      final cmd = catalog.buildCommand('fill_form', {
        'fields': <Map<String, Object?>>[
          {'ref': 's_0', 'text': 'alice'},
          {'ref': 's_1', 'text': 'bob'},
        ],
        'snapshotId': 42,
      }) as FillFormCommand;
      expect(cmd.fields, hasLength(2));
      expect(cmd.fields[0]['ref'], 's_0');
      expect(cmd.fields[1]['text'], 'bob');
      expect(cmd.snapshotId, 42);
    });

    test('snapshotId null when omitted', () {
      final cmd = catalog.buildCommand('fill_form', {
        'fields': <Map<String, Object?>>[
          {'ref': 's_0', 'text': 'x'},
        ],
      }) as FillFormCommand;
      expect(cmd.snapshotId, isNull);
    });
  });

  group('HoverCommand', () {
    test('round-trips ref + snapshotId', () {
      final cmd = catalog.buildCommand('hover', {
        'ref': 's_3',
        'snapshotId': 7,
      }) as HoverCommand;
      expect(cmd.ref, 's_3');
      expect(cmd.snapshotId, 7);
    });
  });
}
```

Run:
```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_server_dart && \
  flutter test test/p2_commands_test.dart > /tmp/p2_t3a.log 2>&1
echo "exit=$?"; tail -10 /tmp/p2_t3a.log
```
Expected: PASS — Task 1 already implemented the build paths; this test is a regression guard.

- [ ] **Step 2: Replace `_fillForm` and `_hover` dispatch stubs with real executors**

In `command_executor.dart`, find the two stub arms in `_dispatch`. Replace:

```dart
      FillFormCommand() => _fillForm(command),
      HoverCommand() => _hover(command),
```

Then append after the last P1 executor (`_navigate`):

```dart
  Future<CoreResult> _fillForm(final FillFormCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    if (command.fields.isEmpty) {
      return CoreResult.failure(
        code: CoreErrorCode.fillFormFailed,
        message: 'fill_form: fields list is empty',
      );
    }

    final results = <Map<String, Object?>>[];
    for (var i = 0; i < command.fields.length; i++) {
      final field = command.fields[i];
      final ref = field['ref'];
      final text = field['text'];
      if (ref is! String || ref.isEmpty || text is! String) {
        return CoreResult.failure(
          code: CoreErrorCode.fillFormFailed,
          message: 'fill_form: field $i missing ref/text',
          details: {'failedAt': i, 'field': field, 'results': results},
        );
      }

      // Apply snapshotId on the first field only — subsequent fields
      // would re-validate against the same id, so just trust the chain.
      final result = await _enterText(EnterTextCommand(
        ref: ref,
        text: text,
        snapshotId: i == 0 ? command.snapshotId : null,
      ));
      results.add(_map(result.data));
      if (!result.ok) {
        return CoreResult.failure(
          code: CoreErrorCode.fillFormFailed,
          message: 'fill_form: field $i (ref=$ref) failed',
          details: {
            'failedAt': i,
            'failedRef': ref,
            'results': results,
            'underlyingError': result.error?.code,
          },
        );
      }
    }

    return CoreResult.success(data: <String, Object?>{
      'success': true,
      'fieldCount': command.fields.length,
      'results': results,
    });
  }

  Future<CoreResult> _hover(final HoverCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.hover,
        args: {
          'ref': command.ref,
          if (command.snapshotId != null) 'snapshotId': command.snapshotId,
        },
      );
      final data = _map(result.json);
      if (data['success'] != true) {
        return CoreResult.failure(
          code: CoreErrorCode.hoverFailed,
          message: 'hover failed: ${data['error']}',
          details: data,
        );
      }
      return CoreResult.success(data: data);
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.hoverFailed,
        message: 'Failed to execute hover: $e',
      );
    }
  }
```

`_map` is already used by sibling executors and is in scope. `EnterTextCommand` is already imported (the dispatch arm `EnterTextCommand() => _enterText(command)` exists at the top of the switch).

- [ ] **Step 3: Add Tool definitions in `interaction_handler.dart`**

After `navigateTool` (the last P1 tool), append:

```dart
  static final fillFormTool = Tool(
    name: 'fill_form',
    description: _description(
      'fill_form',
      'Batch text entry: enters text into multiple fields in one call. '
          'Stops on first failure. Each field: {ref, text}. Pass snapshotId '
          'to validate against the most recent semantic_snapshot (checked '
          'on the first field only).',
    ),
    inputSchema: strictToolInputSchema(
      required: ['fields'],
      properties: {
        'fields': Schema.list(
          items: Schema.object(
            additionalProperties: false,
            properties: {
              'ref': Schema.string(),
              'text': Schema.string(),
            },
            required: ['ref', 'text'],
          ),
        ),
        'snapshotId': Schema.int(),
      },
    ),
  );

  static final hoverTool = Tool(
    name: 'hover',
    description: _description(
      'hover',
      'Synthesize a mouse hover at the centre of a widget by semantic ref. '
          'Drives MouseRegion.onEnter/onExit. Desktop/web only — mobile has '
          'no hover concept. Pass snapshotId for staleness detection.',
    ),
    inputSchema: strictToolInputSchema(
      required: ['ref'],
      properties: {
        'ref': Schema.string(),
        'snapshotId': Schema.int(),
      },
    ),
  );
```

If `Schema.list` is not the project's helper for array schemas, fall back to a raw map literal — verify by searching for `'type': 'array'` usage in the project. The existing `live_edit_handler.dart` may have an example.

- [ ] **Step 4: Add handler methods**

After `navigate`, append:

```dart
  Future<CallToolResult> fillForm(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final args = request.arguments ?? const {};
    final fieldsRaw = args['fields'];
    final fields = fieldsRaw is List
        ? fieldsRaw
            .map<Map<String, Object?>>((final e) {
              if (e is Map<String, Object?>) return e;
              if (e is Map) return e.cast<String, Object?>();
              return const <String, Object?>{};
            })
            .toList(growable: false)
        : const <Map<String, Object?>>[];
    final snapshotIdRaw = jsonDecodeInt(args['snapshotId']);
    final result = await executor.execute(FillFormCommand(
      fields: fields,
      snapshotId: snapshotIdRaw == 0 ? null : snapshotIdRaw,
    ));
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'fill_form failed');
    }
    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> hover(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final args = request.arguments ?? const {};
    final ref = jsonDecodeString(args['ref']);
    final snapshotIdRaw = jsonDecodeInt(args['snapshotId']);
    final result = await executor.execute(HoverCommand(
      ref: ref,
      snapshotId: snapshotIdRaw == 0 ? null : snapshotIdRaw,
    ));
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'hover failed');
    }
    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }
```

- [ ] **Step 5: Register both tools**

In `flutter_inspector.dart`, after the `navigateTool` registration (around line 121), append:

```dart
    registerTool(
      InteractionHandler.fillFormTool,
      _interactionHandler.fillForm,
    );
    registerTool(
      InteractionHandler.hoverTool,
      _interactionHandler.hover,
    );
```

- [ ] **Step 6: Build and test**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter && make build > /tmp/p2_t3b.log 2>&1
echo "build exit=$?"; tail -15 /tmp/p2_t3b.log
```
Expected: clean build.

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_server_dart && \
  flutter test test/p2_commands_test.dart test/command_catalog_test.dart \
  > /tmp/p2_t3c.log 2>&1
echo "test exit=$?"; tail -15 /tmp/p2_t3c.log
```
Expected: 22 catalog + 3 p2_commands = 25 tests, all green.

The two pre-existing test failures (`core_executor_test.dart`, `preconnect_test.dart`) are unrelated; do NOT run them.

- [ ] **Step 7: Commit**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter && \
  git add mcp_server_dart/lib/src/shared_core/command_executor.dart \
          mcp_server_dart/lib/src/mcp_toolkit_server/handlers/interaction_handler.dart \
          mcp_server_dart/lib/src/mcp_toolkit_server/mixins/flutter_inspector.dart \
          mcp_server_dart/test/p2_commands_test.dart && \
  git commit -m "feat(p2): server executors + handlers + registrations

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Memory + roadmap update

**Files:**
- Modify: `~/.claude/projects/-Users-antonio-mcp-cline-mcp-flutter/memory/project_mcp_flutter_interaction_layer.md`
- Modify: `todo/playwright_parity_roadmap.md`
- Modify: `todo/playwright_parity_audit.md`

- [ ] **Step 1: Append a P2 section to the interaction-layer memory**

Mirror the P1 section's shape:
- List the two new tools (and the deferred `select_option`).
- Note `fillForm` is server-side orchestration with no toolkit service / no extension RPC name.
- Note the hover mouse-tracker priming requirement.

Keep under 20 lines.

- [ ] **Step 2: Mark P2 shipped in the roadmap**

In `todo/playwright_parity_roadmap.md`, update:

```diff
-| **P2**   | Form ergonomics + hover                 | Small batch    | Token wins (`fill_form`, `select_option`) + desktop/web (`hover`).  |
+| **P2** ✅ | fill_form + hover *(shipped 2026-04-27, select_option deferred)* | Small batch    | Token wins (`fill_form`) + desktop/web (`hover`). select_option dropped — expressible as tap → wait_for → tap post-P0. |
```

- [ ] **Step 3: Note `select_option` deferral in the audit**

In `todo/playwright_parity_audit.md`, in the gap matrix, change `select_option` from ❌ missing to:

```
| `select_option`                   | ➖ deferred                                      | Expressible as `tap_widget → wait_for(text=label) → tap_widget` post-P0; thin wrapper would save zero round-trips. Revisit if usage data shows the wrapper is worth the surface area. |
```

- [ ] **Step 4: Commit**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter && \
  git add todo/playwright_parity_roadmap.md \
          todo/playwright_parity_audit.md && \
  git commit -m "docs(p2): mark P2 shipped, note select_option deferral

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

(Memory file lives outside the repo; no commit needed — it's a personal note.)

---

## Self-review checklist

**1. Spec coverage.**
- `fill_form` → Tasks 1, 3 (server-side only, no toolkit task)
- `hover` → Tasks 1, 2, 3
- Memory + roadmap + audit → Task 4

**2. No placeholders.** Every code step has actual code. The "verify the helper exists" notes (e.g. Task 2 step 3 about `_refNotFound`/`_now`/`_waitFrame`, Task 3 step 3 about `Schema.list`) are explicit "look here" hints, not handwaves.

**3. Type consistency.** Names align: `fill_form` / `fillForm` / `FillFormCommand` / `fillFormTool` / `fillForm` (handler) / `_fillForm` (executor) / `fill_form_failed`. Same for `hover`.

**4. Branch.** Stays on `live-edit-v2-plannig` per the same instruction as P0/P1.

**5. Roadmap link.** P2 in `todo/playwright_parity_roadmap.md` points here.

**6. Drift watch.** P0 had two plan-vs-code drifts at exec time; P1 had two more. The most likely P2 landmines:
- `_enterText` may have an internal snapshot-id staleness check that fires per-field — confirm in step 2 of Task 3 (the regression test) before assuming the loop "just works."
- `PointerHoverEvent` under FakeAsync — does `tester.pump()` after dispatch trigger `MouseTracker` to re-evaluate? Verify in Task 2 step 4 before proceeding.

---

## Execution handoff

Plan saved to `docs/superpowers/plans/2026-04-27-p2-fill-form-hover.md`. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review per task. Mirror P0/P1 flow.
2. **Inline Execution** — execute tasks in this session with checkpoints.

Defaulting to subagent-driven since P0/P1 went well. The user said "continue with P2" so proceeding without re-asking.
