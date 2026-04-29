# P1: Keyboard + Dialog + Navigate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land three Playwright-parity MCP tools — `press_key`, `handle_dialog`, `navigate` — in one bundle, sharing one new toolkit service file and one new opt-in app-binding API (Navigator key registration).

**Architecture:** All three tools follow the wait_for blueprint (single VM-service extension per tool, server forwards via `callFlutterExtension`, toolkit-side service does the work). One new file `control_flow_service.dart` houses the three implementations. `MCPToolkitBinding` gains a `setNavigatorKey(GlobalKey<NavigatorState>)` setter mirroring the existing `setSelectAtPointHandler` precedent — apps must register a key for `handle_dialog` and `navigate` to work; `press_key` requires no registration. A new typed error `navigator_not_registered` (HTTP 400, non-retryable — caller must fix their app code) covers the missing-key path.

**Tech Stack:** Dart, Flutter (`HardwareKeyboard`, `LogicalKeyboardKey`, `Navigator`, `flutter_test`), the `dart_mcp` server SDK, the project's `CoreCommandExecutor` + `CommandSpec` registry. Reference plan: `docs/superpowers/plans/2026-04-27-wait-for.md` (P0, shipped) — the registration patterns, naming conventions, and TDD scaffolding mirror it exactly.

---

## Decisions locked in

These were the open design points from the roadmap. Recording answers so the engineer doesn't re-litigate during execution.

1. **`press_key` API (post-implementation finding).** Single-path APIs do **not** reach `Focus.onKeyEvent` under the test binding. The shipped implementation uses **both**: (a) `HardwareKeyboard.instance.handleKeyEvent(KeyDownEvent/KeyUpEvent)` to update pressed-key state and notify HardwareKeyboard listeners (Shortcuts, Actions), AND (b) `ServicesBinding.instance.keyEventManager.keyMessageHandler?.call(KeyMessage([event], null))` to invoke the FocusManager-installed handler that walks the focus tree. `handleKeyData`'s pairing buffer is bypassed because we don't send a matching legacy raw event. **Limitation:** `TextField.onSubmitted` is unreachable — it goes through the `flutter/textinput` channel (`TextInputAction.done`), not key events. Documented in the tool description; users should `tap_widget` the submit button instead.
2. **Key-name vocabulary.** Accepted strings: `'Enter'`, `'Escape'`, `'Tab'`, `'Backspace'`, `'Delete'`, `'Space'`, `'ArrowUp'`, `'ArrowDown'`, `'ArrowLeft'`, `'ArrowRight'`, plus single ASCII chars (`'a'`…`'z'`, `'0'`…`'9'`). Map to `LogicalKeyboardKey` constants via a static `_keyMap`. Anything else returns a structured `press_key_failed` error with `unknown_key` detail.
3. **Modifiers.** Optional bool args: `ctrl`, `shift`, `alt`, `meta`. When set, send the corresponding modifier-key down events first, then the main key, then up in reverse order (mirrors a real user). Skip in v1 if the implementer hits a snag — log it as a known limitation.
4. **`handle_dialog` shape (simplified).** Only `dismiss` is first-class. `accept` was dropped — it's a thin wrapper over `wait_for → tap_widget`, and the whole point of `wait_for` returning the snapshot was to avoid those round-trips. `dismiss` calls `Navigator.pop` on the registered navigator's topmost route; returns `popped: true` + the route name on success, structured failure if no popup-class route is on top or no navigator is registered.
5. **`navigate` actions.** Three: `push` (`unawaited(pushNamed(route, arguments))` — pushNamed's Future only resolves on pop, not on display, so awaiting it deadlocks), `pop` (`maybePop()`), `popUntil` (`popUntil(ModalRoute.withName(route))`). All require a registered navigator key. Args use the action enum — no kind union here, just an `action: String` arg. Precheck only on `navigatorKey == null` (not `currentState == null`); `currentState` may be null transiently before the navigator is mounted, but `unknown_action` should still be reported as `unknown_action`, not `navigator_not_registered`.
6. **Test pattern.** None of these tools need `wait_for`'s parallel-pump pattern. They're synchronous: act → `tester.pump()` → assert. `press_key` needs `testWidgets` (focus tree). `handle_dialog` and `navigate` need `testWidgets` (Navigator). No `Future.delayed` deadlock risk because the implementations don't await user-time delays.
7. **Wire format.** Same as wait_for: extension RPC args are stringly-typed. Server `_pressKey` etc. call `jsonEncode` on any nested map (none expected for these tools — args are scalars/strings/bools). Toolkit decodes via `jsonDecodeBool`/`jsonDecodeString`/`jsonDecodeInt` per arg.

---

## File structure

### Create
- `mcp_toolkit/mcp_toolkit/lib/src/services/control_flow_service.dart` — three static methods: `pressKey`, `dismissDialog`, `navigate`. Keymap and modifier helpers.
- `mcp_toolkit/mcp_toolkit/test/control_flow_service_test.dart` — widget tests, one per tool plus error-path coverage.
- `mcp_server_dart/test/p1_commands_test.dart` — regression-guard for the three new catalog build paths.

### Modify
- `mcp_toolkit/mcp_toolkit/lib/src/mcp_toolkit_binding.dart` — add `_navigatorKey` field + `setNavigatorKey` setter + `navigatorKey` getter.
- `mcp_toolkit/mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart` — add three new `OnXxxEntry` extension types and register in `getInteractionToolkitEntries()`.
- `mcp_server_dart/lib/src/mcp_toolkit_consts.dart` — add `pressKey`, `handleDialog`, `navigate` to all three records.
- `mcp_server_dart/lib/src/shared_core/commands/visual_widget_commands.dart` — `PressKeyCommand`, `HandleDialogCommand`, `NavigateCommand`.
- `mcp_server_dart/lib/src/shared_core/commands/commands_specs.dart` — three `CommandSpec` entries.
- `mcp_server_dart/lib/src/shared_core/types/error_codes.dart` — `pressKeyFailed`, `handleDialogFailed`, `navigateFailed`, `navigatorNotRegistered`.
- `mcp_server_dart/lib/src/shared_core/command_executor.dart` — three new dispatch arms + `_pressKey`/`_handleDialog`/`_navigate` methods.
- `mcp_server_dart/lib/src/mcp_toolkit_server/handlers/interaction_handler.dart` — three `Tool` definitions + three handler methods.
- `mcp_server_dart/lib/src/mcp_toolkit_server/mixins/flutter_inspector.dart` — three `registerTool` calls.
- `mcp_server_dart/test/command_catalog_test.dart` — extend with 3 presence checks.

---

## Task 1: Server-side scaffolding for all 3 tools

Mirror Task 1 of the wait_for plan: add command classes, error codes, extension constants, command specs, and dispatch stubs (Dart's sealed-class exhaustiveness forces the stubs). No behavior, just registration.

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
    test('press_key, handle_dialog, navigate commands are registered', () {
      for (final name in ['press_key', 'handle_dialog', 'navigate']) {
        final spec = catalog.specFor(name);
        expect(spec, isNotNull, reason: '$name spec missing');
        expect(spec!.mcpExposed, isTrue, reason: '$name not mcpExposed');
      }

      final pk = catalog.buildCommand('press_key', {
        'key': 'Enter',
        'shift': true,
      }) as PressKeyCommand;
      expect(pk.key, 'Enter');
      expect(pk.shift, isTrue);

      final hd = catalog.buildCommand('handle_dialog', {
        'action': 'dismiss',
      }) as HandleDialogCommand;
      expect(hd.action, 'dismiss');

      final nv = catalog.buildCommand('navigate', {
        'action': 'push',
        'route': '/settings',
      }) as NavigateCommand;
      expect(nv.action, 'push');
      expect(nv.route, '/settings');
    });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_server_dart && \
  flutter test test/command_catalog_test.dart > /tmp/p1_t1a.log 2>&1
echo "exit=$?"; tail -20 /tmp/p1_t1a.log
```
Expected: FAIL — none of the three command classes exist.

- [ ] **Step 3: Add command classes**

Append to `visual_widget_commands.dart` after `WaitForCommand`:

```dart
final class PressKeyCommand extends CoreCommand {
  const PressKeyCommand({
    required this.key,
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
    this.meta = false,
  });

  /// Key name. Accepted: Enter, Escape, Tab, Backspace, Delete, Space,
  /// ArrowUp/Down/Left/Right, single ASCII chars (a..z, 0..9).
  final String key;
  final bool ctrl;
  final bool shift;
  final bool alt;
  final bool meta;

  @override
  String get name => 'press_key';
}

final class HandleDialogCommand extends CoreCommand {
  const HandleDialogCommand({required this.action});

  /// Currently only `'dismiss'` is supported.
  final String action;

  @override
  String get name => 'handle_dialog';
}

final class NavigateCommand extends CoreCommand {
  const NavigateCommand({
    required this.action,
    this.route,
    this.arguments,
  });

  /// One of: `'push'`, `'pop'`, `'popUntil'`.
  final String action;

  /// Required for `'push'` and `'popUntil'`. Ignored for `'pop'`.
  final String? route;

  /// Optional. Used only for `'push'`.
  final Map<String, Object?>? arguments;

  @override
  String get name => 'navigate';
}
```

- [ ] **Step 4: Add error codes**

In `error_codes.dart`, append after `waitForFailed`:

```dart
  static const pressKeyFailed = 'press_key_failed';
  static const handleDialogFailed = 'handle_dialog_failed';
  static const navigateFailed = 'navigate_failed';
  static const navigatorNotRegistered = 'navigator_not_registered';
```

In the same file, append to `_descriptorMap` after `waitForFailed`'s entry:

```dart
      CoreErrorCode.pressKeyFailed: CoreErrorDescriptor(
        code: CoreErrorCode.pressKeyFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.handleDialogFailed: CoreErrorDescriptor(
        code: CoreErrorCode.handleDialogFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.navigateFailed: CoreErrorDescriptor(
        code: CoreErrorCode.navigateFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.navigatorNotRegistered: CoreErrorDescriptor(
        code: CoreErrorCode.navigatorNotRegistered,
        category: CoreErrorCategory.client,
        retryable: false,
        exitCode: 64,
        httpLikeStatus: 400,
      ),
```

If `CoreErrorCategory.client` doesn't exist, fall back to `execution` and flag in your report. (Verify in the existing `error_codes.dart`'s `CoreErrorCategory` enum/class definition — sibling categories should already include something like `client`/`validation`.)

- [ ] **Step 5: Add extension constants**

In `mcp_server_dart/lib/src/mcp_toolkit_consts.dart`, append `pressKey`, `handleDialog`, `navigate` to all three records (`mcpToolkitExtKeys`, `allMcpToolkitExtNames`, `mcpToolkitExtNames`). Mirror exactly how `waitFor` was added in the wait_for series — same three sites, same `mcpToolkitExt.<name>` pattern.

```dart
// mcpToolkitExtKeys (record literal):
  pressKey: '$mcpToolkitExt.${mcpToolkitExtNames.pressKey}',
  handleDialog: '$mcpToolkitExt.${mcpToolkitExtNames.handleDialog}',
  navigate: '$mcpToolkitExt.${mcpToolkitExtNames.navigate}',

// allMcpToolkitExtNames (set):
  mcpToolkitExtNames.pressKey,
  mcpToolkitExtNames.handleDialog,
  mcpToolkitExtNames.navigate,

// mcpToolkitExtNames (record literal):
  pressKey: 'press_key',
  handleDialog: 'handle_dialog',
  navigate: 'navigate',
```

- [ ] **Step 6: Add CommandSpec entries**

In `commands_specs.dart`, after the `wait_for` spec (around line 945), insert:

```dart
      CommandSpec(
        name: 'press_key',
        description:
            'Synthesize a keyboard key press (down + up). Accepted keys: '
            'Enter, Escape, Tab, Backspace, Delete, Space, ArrowUp/Down/'
            'Left/Right, and single ASCII chars (a-z, 0-9). Optional '
            'modifiers: ctrl, shift, alt, meta.',
        inputSchema: _objectSchema(
          required: const ['key'],
          properties: {
            'key': _stringSchema(),
            'ctrl': _boolSchema(),
            'shift': _boolSchema(),
            'alt': _boolSchema(),
            'meta': _boolSchema(),
          },
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) => PressKeyCommand(
          key: _stringArg(args, 'key', fallback: ''),
          ctrl: _boolArg(args, 'ctrl', fallback: false),
          shift: _boolArg(args, 'shift', fallback: false),
          alt: _boolArg(args, 'alt', fallback: false),
          meta: _boolArg(args, 'meta', fallback: false),
        ),
      ),
      CommandSpec(
        name: 'handle_dialog',
        description:
            'Dismiss the topmost popup/dialog route on the registered '
            'Navigator. Currently only action="dismiss" is supported. '
            'Requires the app to register a navigator key via '
            'MCPToolkitBinding.instance.setNavigatorKey(key).',
        inputSchema: _objectSchema(
          required: const ['action'],
          properties: {
            'action': _stringSchema(),
          },
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) => HandleDialogCommand(
          action: _stringArg(args, 'action', fallback: 'dismiss'),
        ),
      ),
      CommandSpec(
        name: 'navigate',
        description:
            'Drive the registered Navigator: push a named route, pop the '
            'topmost route, or popUntil a named route. Requires '
            'MCPToolkitBinding.instance.setNavigatorKey(key) on the app.',
        inputSchema: _objectSchema(
          required: const ['action'],
          properties: {
            'action': _stringSchema(),
            'route': _stringSchema(),
            'arguments': _objectSchema(additionalProperties: true),
          },
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) => NavigateCommand(
          action: _stringArg(args, 'action', fallback: 'push'),
          route: _stringArg(args, 'route', fallback: '').isEmpty
              ? null
              : _stringArg(args, 'route', fallback: ''),
          arguments: _mapArg(args, 'arguments').isEmpty
              ? null
              : _mapArg(args, 'arguments'),
        ),
      ),
```

If `_stringSchema`, `_boolSchema`, or `_boolArg`/`_stringArg` helpers are not present in `commands_specs.dart`, look for sibling helpers (e.g. `_intSchema` is on line 1721; `_intArg` is used in many specs). Use whatever the file's existing convention is — don't invent new helpers.

- [ ] **Step 7: Add dispatch stubs**

In `command_executor.dart`, find the `_dispatch` switch (around line 374). Add three new arms after the `WaitForCommand()` arm:

```dart
      PressKeyCommand() => Future.value(
        CoreResult.failure(
          code: CoreErrorCode.pressKeyFailed,
          message: 'press_key is registered but not yet implemented',
        ),
      ),
      HandleDialogCommand() => Future.value(
        CoreResult.failure(
          code: CoreErrorCode.handleDialogFailed,
          message: 'handle_dialog is registered but not yet implemented',
        ),
      ),
      NavigateCommand() => Future.value(
        CoreResult.failure(
          code: CoreErrorCode.navigateFailed,
          message: 'navigate is registered but not yet implemented',
        ),
      ),
```

(The wait_for series proved this is required by Dart's sealed-class exhaustiveness — adding a `CoreCommand` subtype without a switch arm fails compilation.)

- [ ] **Step 8: Run test to verify it passes**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_server_dart && \
  flutter test test/command_catalog_test.dart > /tmp/p1_t1b.log 2>&1
echo "exit=$?"; tail -10 /tmp/p1_t1b.log
```
Expected: PASS, all 18 tests in the file (17 pre-existing + 1 new).

- [ ] **Step 9: Commit (from repo root)**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter && \
  git add mcp_server_dart/lib/src/shared_core/types/error_codes.dart \
          mcp_server_dart/lib/src/shared_core/commands/visual_widget_commands.dart \
          mcp_server_dart/lib/src/shared_core/commands/commands_specs.dart \
          mcp_server_dart/lib/src/mcp_toolkit_consts.dart \
          mcp_server_dart/lib/src/shared_core/command_executor.dart \
          mcp_server_dart/test/command_catalog_test.dart && \
  git commit -m "feat(p1): scaffold press_key, handle_dialog, navigate commands

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Navigator-key registration on `MCPToolkitBinding`

Add the opt-in registration API. Apps call `MCPToolkitBinding.instance.setNavigatorKey(key)` to enable `handle_dialog` and `navigate`.

**Files:**
- Modify: `mcp_toolkit/mcp_toolkit/lib/src/mcp_toolkit_binding.dart`
- Create: `mcp_toolkit/mcp_toolkit/test/navigator_key_registration_test.dart`

- [ ] **Step 1: Write failing test**

Create `mcp_toolkit/mcp_toolkit/test/navigator_key_registration_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  test('navigatorKey defaults to null', () {
    final binding = MCPToolkitBinding.instance;
    expect(binding.navigatorKey, isNull);
  });

  test('setNavigatorKey stores the key for later retrieval', () {
    final key = GlobalKey<NavigatorState>();
    MCPToolkitBinding.instance.setNavigatorKey(key);
    expect(MCPToolkitBinding.instance.navigatorKey, same(key));
    // Reset for other tests.
    MCPToolkitBinding.instance.setNavigatorKey(null);
    expect(MCPToolkitBinding.instance.navigatorKey, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_toolkit/mcp_toolkit && \
  flutter test test/navigator_key_registration_test.dart > /tmp/p1_t2a.log 2>&1
echo "exit=$?"; tail -10 /tmp/p1_t2a.log
```
Expected: FAIL — `navigatorKey` and `setNavigatorKey` don't exist.

- [ ] **Step 3: Add the API**

In `mcp_toolkit_binding.dart`, locate the `_selectAtPointHandler` field (around line 60). Mirror the pattern by adding immediately after it (before `setSelectAtPointHandler`):

```dart
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Optional `GlobalKey<NavigatorState>` registered by the app to enable
  /// `handle_dialog` and `navigate` MCP tools.
  ///
  /// Apps register via [setNavigatorKey]; if unset, the dependent tools
  /// fail with a `navigator_not_registered` error.
  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;

  /// Registers (or clears, when [key] is null) the Navigator key used by
  /// `handle_dialog` and `navigate`. Pass the same key your `MaterialApp`
  /// or `WidgetsApp` was constructed with.
  void setNavigatorKey(final GlobalKey<NavigatorState>? key) {
    _navigatorKey = key;
  }
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_toolkit/mcp_toolkit && \
  flutter test test/navigator_key_registration_test.dart > /tmp/p1_t2b.log 2>&1
echo "exit=$?"; tail -10 /tmp/p1_t2b.log
```
Expected: PASS — both tests.

- [ ] **Step 5: Commit**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter && \
  git add mcp_toolkit/mcp_toolkit/lib/src/mcp_toolkit_binding.dart \
          mcp_toolkit/mcp_toolkit/test/navigator_key_registration_test.dart && \
  git commit -m "feat(p1): MCPToolkitBinding.setNavigatorKey opt-in API

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `press_key` toolkit service + MCP entry

**Files:**
- Create: `mcp_toolkit/mcp_toolkit/lib/src/services/control_flow_service.dart`
- Create: `mcp_toolkit/mcp_toolkit/test/control_flow_service_test.dart`
- Modify: `mcp_toolkit/mcp_toolkit/lib/mcp_toolkit.dart` (export the service)
- Modify: `mcp_toolkit/mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart` (add entry + register)

- [ ] **Step 1: Write the failing test**

Create `mcp_toolkit/mcp_toolkit/test/control_flow_service_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  // -----------------------------------------------------------------------
  // press_key
  // -----------------------------------------------------------------------

  testWidgets('press_key Enter on a focused TextField submits onSubmitted',
      (final tester) async {
    String? submitted;
    final controller = TextEditingController(text: 'hello');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TextField(
              autofocus: true,
              controller: controller,
              onSubmitted: (final v) => submitted = v,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final result = await ControlFlowService.pressKey(key: 'Enter');
    await tester.pump();

    expect(result['success'], isTrue);
    expect(result['key'], 'Enter');
    expect(submitted, 'hello');
  });

  test('press_key rejects unknown key with structured failure', () async {
    final result = await ControlFlowService.pressKey(key: 'BogusKey');
    expect(result['success'], isFalse);
    expect(result['error'], 'unknown_key');
    expect(result['key'], 'BogusKey');
  });

  test('press_key rejects empty key', () async {
    final result = await ControlFlowService.pressKey(key: '');
    expect(result['success'], isFalse);
    expect(result['error'], 'unknown_key');
  });
}
```

(Other tools' tests are appended in their own tasks below.)

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_toolkit/mcp_toolkit && \
  flutter test test/control_flow_service_test.dart > /tmp/p1_t3a.log 2>&1
echo "exit=$?"; tail -15 /tmp/p1_t3a.log
```
Expected: FAIL — `ControlFlowService` undefined.

- [ ] **Step 3: Create `ControlFlowService` with `pressKey`**

Create `mcp_toolkit/mcp_toolkit/lib/src/services/control_flow_service.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../mcp_toolkit_binding.dart';

/// Toolkit-side implementation of P1 control-flow MCP tools:
/// `press_key`, `handle_dialog`, `navigate`.
class ControlFlowService {
  const ControlFlowService._();

  // -------------------------------------------------------------------------
  // press_key
  // -------------------------------------------------------------------------

  /// Map of accepted key names to LogicalKeyboardKey constants.
  static final Map<String, LogicalKeyboardKey> _namedKeys = {
    'Enter': LogicalKeyboardKey.enter,
    'Escape': LogicalKeyboardKey.escape,
    'Tab': LogicalKeyboardKey.tab,
    'Backspace': LogicalKeyboardKey.backspace,
    'Delete': LogicalKeyboardKey.delete,
    'Space': LogicalKeyboardKey.space,
    'ArrowUp': LogicalKeyboardKey.arrowUp,
    'ArrowDown': LogicalKeyboardKey.arrowDown,
    'ArrowLeft': LogicalKeyboardKey.arrowLeft,
    'ArrowRight': LogicalKeyboardKey.arrowRight,
  };

  static LogicalKeyboardKey? _resolveKey(final String name) {
    if (name.isEmpty) return null;
    final named = _namedKeys[name];
    if (named != null) return named;
    if (name.length != 1) return null;
    final code = name.codeUnitAt(0);
    // Lowercase letters
    if (code >= 0x61 && code <= 0x7A) {
      return LogicalKeyboardKey(code);
    }
    // Digits
    if (code >= 0x30 && code <= 0x39) {
      return LogicalKeyboardKey(code);
    }
    return null;
  }

  /// Synthesize a key-down + key-up via [HardwareKeyboard].
  static Future<Map<String, Object?>> pressKey({
    required final String key,
    final bool ctrl = false,
    final bool shift = false,
    final bool alt = false,
    final bool meta = false,
  }) async {
    final logical = _resolveKey(key);
    if (logical == null) {
      return <String, Object?>{
        'success': false,
        'error': 'unknown_key',
        'key': key,
      };
    }

    final keyboard = HardwareKeyboard.instance;
    final modifiers = <LogicalKeyboardKey>[
      if (ctrl) LogicalKeyboardKey.controlLeft,
      if (shift) LogicalKeyboardKey.shiftLeft,
      if (alt) LogicalKeyboardKey.altLeft,
      if (meta) LogicalKeyboardKey.metaLeft,
    ];

    final stamp = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);

    // Press modifiers down, in order.
    for (final mod in modifiers) {
      keyboard.handleKeyEvent(KeyDownEvent(
        physicalKey: PhysicalKeyboardKey(mod.keyId),
        logicalKey: mod,
        timeStamp: stamp,
      ));
    }
    // Main key down + up.
    keyboard.handleKeyEvent(KeyDownEvent(
      physicalKey: PhysicalKeyboardKey(logical.keyId),
      logicalKey: logical,
      timeStamp: stamp,
    ));
    keyboard.handleKeyEvent(KeyUpEvent(
      physicalKey: PhysicalKeyboardKey(logical.keyId),
      logicalKey: logical,
      timeStamp: stamp,
    ));
    // Release modifiers in reverse order.
    for (final mod in modifiers.reversed) {
      keyboard.handleKeyEvent(KeyUpEvent(
        physicalKey: PhysicalKeyboardKey(mod.keyId),
        logicalKey: mod,
        timeStamp: stamp,
      ));
    }

    // Yield a frame so listeners observe the events before we return.
    await WidgetsBinding.instance.endOfFrame;

    return <String, Object?>{
      'success': true,
      'key': key,
      'ctrl': ctrl,
      'shift': shift,
      'alt': alt,
      'meta': meta,
    };
  }
}
```

`PhysicalKeyboardKey(logical.keyId)` is a deliberate approximation — the physical-key USB-HID mapping differs from logical, but for non-platform-channel keystrokes (`HardwareKeyboard.handleKeyEvent` directly) Flutter's focus dispatch only consults `logicalKey`. Verify this assumption is correct by reading the `HardwareKeyboard.handleKeyEvent` source if the test fails.

- [ ] **Step 4: Re-export from package barrel**

Open `mcp_toolkit/mcp_toolkit/lib/mcp_toolkit.dart`. Add (alphabetised among the existing service exports):

```dart
export 'src/services/control_flow_service.dart';
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_toolkit/mcp_toolkit && \
  flutter test test/control_flow_service_test.dart > /tmp/p1_t3b.log 2>&1
echo "exit=$?"; tail -15 /tmp/p1_t3b.log
```
Expected: all 3 tests PASS.

If the `Enter on a focused TextField` test fails (key event not reaching the focus tree), this is the signal flagged in design decision #1 — escalate the API choice rather than silently switching. The plan recommends `HardwareKeyboard.handleKeyEvent`; the alternative is `ServicesBinding.instance.platformDispatcher.onKeyData`.

- [ ] **Step 6: Add the MCP entry**

In `mcp_toolkit/mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart`, append `OnPressKeyEntry()` to `getInteractionToolkitEntries()` (around line 19, after `OnWaitForEntry()`).

Append the entry definition at the bottom of the file (after `OnWaitForEntry`):

```dart
// ---------------------------------------------------------------------------
// Press key
// ---------------------------------------------------------------------------

/// {@template on_press_key_entry}
/// Synthesize a keyboard key press (down + up) with optional modifiers.
/// {@endtemplate}
extension type OnPressKeyEntry._(MCPCallEntry entry) implements MCPCallEntry {
  /// {@macro on_press_key_entry}
  factory OnPressKeyEntry() {
    final entry = MCPCallEntry.tool(
      handler: (final parameters) async {
        final key = jsonDecodeString(parameters['key']);
        final result = await ControlFlowService.pressKey(
          key: key,
          ctrl: jsonDecodeBool(parameters['ctrl']),
          shift: jsonDecodeBool(parameters['shift']),
          alt: jsonDecodeBool(parameters['alt']),
          meta: jsonDecodeBool(parameters['meta']),
        );
        return MCPCallResult(
          message: result['success'] == true
              ? 'press_key dispatched: $key.'
              : 'press_key failed: ${result['error']}.',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'press_key',
        description:
            'Synthesize a keyboard key press (down+up). '
            'Accepted keys: Enter, Escape, Tab, Backspace, Delete, Space, '
            'ArrowUp/Down/Left/Right, single ASCII chars (a-z, 0-9). '
            'Optional modifiers: ctrl, shift, alt, meta.',
        inputSchema: ObjectSchema(
          properties: {
            'key': StringSchema(),
            'ctrl': BooleanSchema(),
            'shift': BooleanSchema(),
            'alt': BooleanSchema(),
            'meta': BooleanSchema(),
          },
          required: const ['key'],
        ),
      ),
    );
    return OnPressKeyEntry._(entry);
  }
}
```

Add the import at the top of the file:
```dart
import '../services/control_flow_service.dart';
```

- [ ] **Step 7: Run package tests to verify nothing regressed**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_toolkit/mcp_toolkit && \
  flutter test > /tmp/p1_t3c.log 2>&1
echo "exit=$?"; tail -20 /tmp/p1_t3c.log
```
Expected: all package tests pass (existing + 3 new from press_key + 2 from navigator-key registration).

- [ ] **Step 8: Commit**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter && \
  git add mcp_toolkit/mcp_toolkit/lib/src/services/control_flow_service.dart \
          mcp_toolkit/mcp_toolkit/lib/mcp_toolkit.dart \
          mcp_toolkit/mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart \
          mcp_toolkit/mcp_toolkit/test/control_flow_service_test.dart && \
  git commit -m "feat(p1): press_key tool + ControlFlowService

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `handle_dialog` (dismiss only)

Adds the dismiss path to `ControlFlowService` and a new MCP entry.

**Files:**
- Modify: `mcp_toolkit/mcp_toolkit/lib/src/services/control_flow_service.dart`
- Modify: `mcp_toolkit/mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart`
- Modify: `mcp_toolkit/mcp_toolkit/test/control_flow_service_test.dart`

- [ ] **Step 1: Append failing tests**

Append inside `void main() { ... }` of `control_flow_service_test.dart`, before the closing brace:

```dart
  // -----------------------------------------------------------------------
  // handle_dialog
  // -----------------------------------------------------------------------

  testWidgets('handle_dialog dismiss pops the topmost AlertDialog',
      (final tester) async {
    final navKey = GlobalKey<NavigatorState>();
    MCPToolkitBinding.instance.setNavigatorKey(navKey);

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      home: Builder(
        builder: (final context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (final _) => const AlertDialog(
                  title: Text('Confirm?'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    // Open the dialog.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    final result = await ControlFlowService.dismissDialog();
    await tester.pumpAndSettle();

    expect(result['success'], isTrue);
    expect(find.byType(AlertDialog), findsNothing);

    MCPToolkitBinding.instance.setNavigatorKey(null);
  });

  testWidgets(
      'handle_dialog dismiss returns failure when no dialog is showing',
      (final tester) async {
    final navKey = GlobalKey<NavigatorState>();
    MCPToolkitBinding.instance.setNavigatorKey(navKey);

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navKey, home: const Scaffold()),
    );

    final result = await ControlFlowService.dismissDialog();
    expect(result['success'], isFalse);
    expect(result['error'], 'no_popup_route');

    MCPToolkitBinding.instance.setNavigatorKey(null);
  });

  test('handle_dialog dismiss fails fast when no navigator registered',
      () async {
    MCPToolkitBinding.instance.setNavigatorKey(null);
    final result = await ControlFlowService.dismissDialog();
    expect(result['success'], isFalse);
    expect(result['error'], 'navigator_not_registered');
  });
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_toolkit/mcp_toolkit && \
  flutter test test/control_flow_service_test.dart --plain-name "handle_dialog" \
  > /tmp/p1_t4a.log 2>&1
echo "exit=$?"; tail -15 /tmp/p1_t4a.log
```
Expected: FAIL — `dismissDialog` undefined.

- [ ] **Step 3: Add `dismissDialog` to `ControlFlowService`**

Append to `ControlFlowService` (after `pressKey`):

```dart
  // -------------------------------------------------------------------------
  // handle_dialog
  // -------------------------------------------------------------------------

  static Future<Map<String, Object?>> dismissDialog() async {
    final navState = MCPToolkitBinding.instance.navigatorKey?.currentState;
    if (navState == null) {
      return <String, Object?>{
        'success': false,
        'error': 'navigator_not_registered',
      };
    }

    Route<Object?>? topRoute;
    navState.popUntil((final r) {
      topRoute ??= r;
      return true;
    });
    final route = topRoute;
    if (route is! PopupRoute) {
      return <String, Object?>{
        'success': false,
        'error': 'no_popup_route',
        'topRouteName': route?.settings.name,
      };
    }

    final popped = await navState.maybePop();
    return <String, Object?>{
      'success': popped,
      'routeName': route.settings.name,
    };
  }
```

The trick of using `popUntil` with a sentinel that always returns `true` and captures the *first* route is the canonical way to inspect the top route without actually popping (Flutter's `Navigator` doesn't expose a public `topRoute`). Alternatively, use `Navigator.of(context).widget` traversal — verify which approach is idiomatic in this codebase by searching for prior `popUntil` usage. If the sentinel pattern feels clever-by-half, reach for `Navigator.of(...).overlay?.entries.last` or whatever the codebase already uses.

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_toolkit/mcp_toolkit && \
  flutter test test/control_flow_service_test.dart > /tmp/p1_t4b.log 2>&1
echo "exit=$?"; tail -15 /tmp/p1_t4b.log
```
Expected: all tests pass (3 press_key + 3 handle_dialog).

- [ ] **Step 5: Add the MCP entry**

In `interaction_toolkit.dart`, append `OnHandleDialogEntry()` to the entries set, then append:

```dart
// ---------------------------------------------------------------------------
// Handle dialog
// ---------------------------------------------------------------------------

/// {@template on_handle_dialog_entry}
/// Dismiss the topmost popup/dialog route on the registered Navigator.
/// {@endtemplate}
extension type OnHandleDialogEntry._(MCPCallEntry entry)
    implements MCPCallEntry {
  /// {@macro on_handle_dialog_entry}
  factory OnHandleDialogEntry() {
    final entry = MCPCallEntry.tool(
      handler: (final parameters) async {
        final action = jsonDecodeString(parameters['action']);
        if (action != 'dismiss') {
          return MCPCallResult(
            message: 'handle_dialog: unsupported action "$action".',
            parameters: <String, Object?>{
              'success': false,
              'error': 'unsupported_action',
              'action': action,
            },
          );
        }
        final result = await ControlFlowService.dismissDialog();
        return MCPCallResult(
          message: result['success'] == true
              ? 'Dialog dismissed.'
              : 'handle_dialog failed: ${result['error']}.',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'handle_dialog',
        description:
            'Dismiss the topmost popup/dialog route on the registered '
            'Navigator. Currently only action="dismiss" is supported. '
            'Requires MCPToolkitBinding.instance.setNavigatorKey(key).',
        inputSchema: ObjectSchema(
          properties: {
            'action': StringSchema(),
          },
          required: const ['action'],
        ),
      ),
    );
    return OnHandleDialogEntry._(entry);
  }
}
```

- [ ] **Step 6: Commit**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter && \
  git add mcp_toolkit/mcp_toolkit/lib/src/services/control_flow_service.dart \
          mcp_toolkit/mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart \
          mcp_toolkit/mcp_toolkit/test/control_flow_service_test.dart && \
  git commit -m "feat(p1): handle_dialog (dismiss) tool

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: `navigate`

Push, pop, popUntil on the registered navigator.

**Files:**
- Modify: `mcp_toolkit/mcp_toolkit/lib/src/services/control_flow_service.dart`
- Modify: `mcp_toolkit/mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart`
- Modify: `mcp_toolkit/mcp_toolkit/test/control_flow_service_test.dart`

- [ ] **Step 1: Append failing tests**

Append to `control_flow_service_test.dart` before the final closing `}`:

```dart
  // -----------------------------------------------------------------------
  // navigate
  // -----------------------------------------------------------------------

  testWidgets('navigate push pushes the named route', (final tester) async {
    final navKey = GlobalKey<NavigatorState>();
    MCPToolkitBinding.instance.setNavigatorKey(navKey);

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      routes: {
        '/': (final _) => const Scaffold(body: Text('home')),
        '/settings': (final _) => const Scaffold(body: Text('settings page')),
      },
    ));
    await tester.pumpAndSettle();

    final result = await ControlFlowService.navigate(
      action: 'push',
      route: '/settings',
    );
    await tester.pumpAndSettle();

    expect(result['success'], isTrue);
    expect(find.text('settings page'), findsOneWidget);

    MCPToolkitBinding.instance.setNavigatorKey(null);
  });

  testWidgets('navigate pop returns to previous route', (final tester) async {
    final navKey = GlobalKey<NavigatorState>();
    MCPToolkitBinding.instance.setNavigatorKey(navKey);

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      routes: {
        '/': (final _) => const Scaffold(body: Text('home')),
        '/inner': (final _) => const Scaffold(body: Text('inner page')),
      },
    ));
    await tester.pumpAndSettle();

    navKey.currentState!.pushNamed('/inner');
    await tester.pumpAndSettle();
    expect(find.text('inner page'), findsOneWidget);

    final result = await ControlFlowService.navigate(action: 'pop');
    await tester.pumpAndSettle();

    expect(result['success'], isTrue);
    expect(find.text('home'), findsOneWidget);

    MCPToolkitBinding.instance.setNavigatorKey(null);
  });

  test('navigate fails fast when no navigator registered', () async {
    MCPToolkitBinding.instance.setNavigatorKey(null);
    final result = await ControlFlowService.navigate(
      action: 'push',
      route: '/x',
    );
    expect(result['success'], isFalse);
    expect(result['error'], 'navigator_not_registered');
  });

  test('navigate rejects unknown action', () async {
    final navKey = GlobalKey<NavigatorState>();
    MCPToolkitBinding.instance.setNavigatorKey(navKey);
    final result = await ControlFlowService.navigate(action: 'teleport');
    expect(result['success'], isFalse);
    expect(result['error'], 'unknown_action');
    MCPToolkitBinding.instance.setNavigatorKey(null);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_toolkit/mcp_toolkit && \
  flutter test test/control_flow_service_test.dart --plain-name "navigate" \
  > /tmp/p1_t5a.log 2>&1
echo "exit=$?"; tail -15 /tmp/p1_t5a.log
```
Expected: FAIL — `navigate` undefined.

- [ ] **Step 3: Add `navigate` to `ControlFlowService`**

Append to `ControlFlowService`:

```dart
  // -------------------------------------------------------------------------
  // navigate
  // -------------------------------------------------------------------------

  static Future<Map<String, Object?>> navigate({
    required final String action,
    final String? route,
    final Map<String, Object?>? arguments,
  }) async {
    final navState = MCPToolkitBinding.instance.navigatorKey?.currentState;
    if (navState == null) {
      return <String, Object?>{
        'success': false,
        'error': 'navigator_not_registered',
      };
    }

    switch (action) {
      case 'push':
        if (route == null || route.isEmpty) {
          return <String, Object?>{
            'success': false,
            'error': 'missing_route',
            'action': action,
          };
        }
        await navState.pushNamed<Object?>(route, arguments: arguments);
        return <String, Object?>{
          'success': true,
          'action': 'push',
          'route': route,
        };
      case 'pop':
        final popped = await navState.maybePop();
        return <String, Object?>{
          'success': popped,
          'action': 'pop',
        };
      case 'popUntil':
        if (route == null || route.isEmpty) {
          return <String, Object?>{
            'success': false,
            'error': 'missing_route',
            'action': action,
          };
        }
        navState.popUntil(ModalRoute.withName(route));
        return <String, Object?>{
          'success': true,
          'action': 'popUntil',
          'route': route,
        };
      default:
        return <String, Object?>{
          'success': false,
          'error': 'unknown_action',
          'action': action,
        };
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_toolkit/mcp_toolkit && \
  flutter test test/control_flow_service_test.dart > /tmp/p1_t5b.log 2>&1
echo "exit=$?"; tail -15 /tmp/p1_t5b.log
```
Expected: all tests pass (3 press_key + 3 handle_dialog + 4 navigate).

- [ ] **Step 5: Add the MCP entry**

In `interaction_toolkit.dart`, append `OnNavigateEntry()` to the entries set, then append:

```dart
// ---------------------------------------------------------------------------
// Navigate
// ---------------------------------------------------------------------------

/// {@template on_navigate_entry}
/// Drive the registered Navigator: push a named route, pop the topmost
/// route, or popUntil a named route.
/// {@endtemplate}
extension type OnNavigateEntry._(MCPCallEntry entry) implements MCPCallEntry {
  /// {@macro on_navigate_entry}
  factory OnNavigateEntry() {
    final entry = MCPCallEntry.tool(
      handler: (final parameters) async {
        final action = jsonDecodeString(parameters['action']);
        final route = jsonDecodeString(parameters['route']);
        final argsRaw = parameters['arguments'];
        final arguments = argsRaw == null || argsRaw.isEmpty
            ? null
            : jsonDecodeMap(argsRaw);
        final result = await ControlFlowService.navigate(
          action: action,
          route: route.isEmpty ? null : route,
          arguments: arguments,
        );
        return MCPCallResult(
          message: result['success'] == true
              ? 'navigate $action ok.'
              : 'navigate failed: ${result['error']}.',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'navigate',
        description:
            'Drive the registered Navigator. action=push|pop|popUntil. '
            'push/popUntil require route. push accepts arguments. '
            'Requires MCPToolkitBinding.instance.setNavigatorKey(key).',
        inputSchema: ObjectSchema(
          properties: {
            'action': StringSchema(),
            'route': StringSchema(),
            'arguments': ObjectSchema(),
          },
          required: const ['action'],
        ),
      ),
    );
    return OnNavigateEntry._(entry);
  }
}
```

- [ ] **Step 6: Run package tests**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_toolkit/mcp_toolkit && \
  flutter test > /tmp/p1_t5c.log 2>&1
echo "exit=$?"; tail -25 /tmp/p1_t5c.log
```
Expected: all package tests still pass.

- [ ] **Step 7: Commit**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter && \
  git add mcp_toolkit/mcp_toolkit/lib/src/services/control_flow_service.dart \
          mcp_toolkit/mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart \
          mcp_toolkit/mcp_toolkit/test/control_flow_service_test.dart && \
  git commit -m "feat(p1): navigate tool (push/pop/popUntil)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Server-side wiring (executor + handlers + registration)

Replace the three Task-1 stubs with real executors, add `Tool` definitions and handlers in `interaction_handler.dart`, register all three in `flutter_inspector.dart`. Mirrors Task 7 of the wait_for plan.

**Files:**
- Modify: `mcp_server_dart/lib/src/shared_core/command_executor.dart`
- Modify: `mcp_server_dart/lib/src/mcp_toolkit_server/handlers/interaction_handler.dart`
- Modify: `mcp_server_dart/lib/src/mcp_toolkit_server/mixins/flutter_inspector.dart`
- Create: `mcp_server_dart/test/p1_commands_test.dart`

- [ ] **Step 1: Write the regression-guard test**

Create `mcp_server_dart/test/p1_commands_test.dart`:

```dart
import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  final catalog = CommandCatalog.instance;

  group('PressKeyCommand', () {
    test('round-trips key + modifiers', () {
      final cmd = catalog.buildCommand('press_key', {
        'key': 'Tab',
        'shift': true,
        'ctrl': true,
      }) as PressKeyCommand;
      expect(cmd.key, 'Tab');
      expect(cmd.shift, isTrue);
      expect(cmd.ctrl, isTrue);
      expect(cmd.alt, isFalse);
      expect(cmd.meta, isFalse);
    });
  });

  group('HandleDialogCommand', () {
    test('default action is dismiss', () {
      final cmd = catalog.buildCommand('handle_dialog', {})
          as HandleDialogCommand;
      expect(cmd.action, 'dismiss');
    });
  });

  group('NavigateCommand', () {
    test('round-trips action + route + arguments', () {
      final cmd = catalog.buildCommand('navigate', {
        'action': 'push',
        'route': '/profile',
        'arguments': {'userId': 42},
      }) as NavigateCommand;
      expect(cmd.action, 'push');
      expect(cmd.route, '/profile');
      expect(cmd.arguments?['userId'], 42);
    });

    test('arguments null when omitted', () {
      final cmd = catalog.buildCommand('navigate', {
        'action': 'pop',
      }) as NavigateCommand;
      expect(cmd.arguments, isNull);
    });
  });
}
```

Run:
```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_server_dart && \
  flutter test test/p1_commands_test.dart > /tmp/p1_t6a.log 2>&1
echo "exit=$?"; tail -10 /tmp/p1_t6a.log
```
Expected: PASS — Task 1 already implemented the build paths; this test is a regression guard.

- [ ] **Step 2: Replace dispatch stubs with real executors**

In `command_executor.dart`, find the three `PressKeyCommand()` / `HandleDialogCommand()` / `NavigateCommand()` stub arms in `_dispatch`. Replace with:

```dart
      PressKeyCommand() => _pressKey(command),
      HandleDialogCommand() => _handleDialog(command),
      NavigateCommand() => _navigate(command),
```

Append after `_waitFor` (around line 1100):

```dart
  Future<CoreResult> _pressKey(final PressKeyCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.pressKey,
        args: {
          'key': command.key,
          'ctrl': command.ctrl,
          'shift': command.shift,
          'alt': command.alt,
          'meta': command.meta,
        },
      );
      final data = _map(result.json);
      if (data['success'] != true) {
        return CoreResult.failure(
          code: data['error'] == 'navigator_not_registered'
              ? CoreErrorCode.navigatorNotRegistered
              : CoreErrorCode.pressKeyFailed,
          message: 'press_key failed: ${data['error']}',
          details: data,
        );
      }
      return CoreResult.success(data: data);
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.pressKeyFailed,
        message: 'Failed to execute press_key: $e',
      );
    }
  }

  Future<CoreResult> _handleDialog(final HandleDialogCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.handleDialog,
        args: {'action': command.action},
      );
      final data = _map(result.json);
      if (data['success'] != true) {
        return CoreResult.failure(
          code: data['error'] == 'navigator_not_registered'
              ? CoreErrorCode.navigatorNotRegistered
              : CoreErrorCode.handleDialogFailed,
          message: 'handle_dialog failed: ${data['error']}',
          details: data,
        );
      }
      return CoreResult.success(data: data);
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.handleDialogFailed,
        message: 'Failed to execute handle_dialog: $e',
      );
    }
  }

  Future<CoreResult> _navigate(final NavigateCommand command) async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) return ensureFailure;

    try {
      final result = await connectionContext.callFlutterExtension(
        mcpToolkitExtKeys.navigate,
        args: {
          'action': command.action,
          if (command.route != null) 'route': command.route,
          if (command.arguments != null)
            'arguments': jsonEncode(command.arguments),
        },
      );
      final data = _map(result.json);
      if (data['success'] != true) {
        return CoreResult.failure(
          code: data['error'] == 'navigator_not_registered'
              ? CoreErrorCode.navigatorNotRegistered
              : CoreErrorCode.navigateFailed,
          message: 'navigate failed: ${data['error']}',
          details: data,
        );
      }
      return CoreResult.success(data: data);
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.navigateFailed,
        message: 'Failed to execute navigate: $e',
      );
    }
  }
```

- [ ] **Step 3: Add Tool definitions in `interaction_handler.dart`**

After `waitForTool`, append three new `static final` Tools:

```dart
  static final pressKeyTool = Tool(
    name: 'press_key',
    description: _description(
      'press_key',
      'Synthesize a keyboard key press (down+up). '
          'Accepted keys: Enter, Escape, Tab, Backspace, Delete, Space, '
          'ArrowUp/Down/Left/Right, single ASCII chars (a-z, 0-9). '
          'Optional modifiers: ctrl, shift, alt, meta.',
    ),
    inputSchema: strictToolInputSchema(
      required: ['key'],
      properties: {
        'key': Schema.string(),
        'ctrl': Schema.bool(),
        'shift': Schema.bool(),
        'alt': Schema.bool(),
        'meta': Schema.bool(),
      },
    ),
  );

  static final handleDialogTool = Tool(
    name: 'handle_dialog',
    description: _description(
      'handle_dialog',
      'Dismiss the topmost popup/dialog route on the registered Navigator. '
          'Currently only action="dismiss" is supported. '
          'Requires MCPToolkitBinding.instance.setNavigatorKey(key) on the app.',
    ),
    inputSchema: strictToolInputSchema(
      required: ['action'],
      properties: {
        'action': Schema.string(description: 'Currently must be "dismiss"'),
      },
    ),
  );

  static final navigateTool = Tool(
    name: 'navigate',
    description: _description(
      'navigate',
      'Drive the registered Navigator: action=push|pop|popUntil. '
          'push and popUntil require route. push accepts arguments map. '
          'Requires MCPToolkitBinding.instance.setNavigatorKey(key) on the app.',
    ),
    inputSchema: strictToolInputSchema(
      required: ['action'],
      properties: {
        'action': Schema.string(),
        'route': Schema.string(),
        'arguments': Schema.object(additionalProperties: true),
      },
    ),
  );
```

- [ ] **Step 4: Add handler methods**

After `waitFor`, append:

```dart
  Future<CallToolResult> pressKey(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final args = request.arguments ?? const {};
    final result = await executor.execute(PressKeyCommand(
      key: jsonDecodeString(args['key']),
      ctrl: jsonDecodeBool(args['ctrl']),
      shift: jsonDecodeBool(args['shift']),
      alt: jsonDecodeBool(args['alt']),
      meta: jsonDecodeBool(args['meta']),
    ));
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'press_key failed');
    }
    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> handleDialog(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final args = request.arguments ?? const {};
    final result = await executor.execute(HandleDialogCommand(
      action: jsonDecodeString(args['action']).whenEmptyUse('dismiss'),
    ));
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'handle_dialog failed');
    }
    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> navigate(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final args = request.arguments ?? const {};
    final route = jsonDecodeString(args['route']);
    final argsMapRaw = args['arguments'];
    final arguments = argsMapRaw is Map
        ? Map<String, Object?>.from(argsMapRaw)
        : null;
    final result = await executor.execute(NavigateCommand(
      action: jsonDecodeString(args['action']).whenEmptyUse('push'),
      route: route.isEmpty ? null : route,
      arguments: arguments == null || arguments.isEmpty ? null : arguments,
    ));
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'navigate failed');
    }
    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }
```

- [ ] **Step 5: Register the three tools**

In `flutter_inspector.dart`, after the `waitForTool` registration, append:

```dart
    registerTool(
      InteractionHandler.pressKeyTool,
      _interactionHandler.pressKey,
    );
    registerTool(
      InteractionHandler.handleDialogTool,
      _interactionHandler.handleDialog,
    );
    registerTool(
      InteractionHandler.navigateTool,
      _interactionHandler.navigate,
    );
```

- [ ] **Step 6: Build and test**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter && make build > /tmp/p1_t6b.log 2>&1
echo "build exit=$?"; tail -15 /tmp/p1_t6b.log
```
Expected: clean build.

```bash
cd /Users/antonio/mcp/cline/mcp_flutter/mcp_server_dart && \
  flutter test test/p1_commands_test.dart test/command_catalog_test.dart \
  > /tmp/p1_t6c.log 2>&1
echo "test exit=$?"; tail -15 /tmp/p1_t6c.log
```
Expected: all green. Pre-existing failures (`core_executor_test.dart`, `preconnect_test.dart`) are unrelated and should NOT be run.

- [ ] **Step 7: Commit**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter && \
  git add mcp_server_dart/lib/src/shared_core/command_executor.dart \
          mcp_server_dart/lib/src/mcp_toolkit_server/handlers/interaction_handler.dart \
          mcp_server_dart/lib/src/mcp_toolkit_server/mixins/flutter_inspector.dart \
          mcp_server_dart/test/p1_commands_test.dart && \
  git commit -m "feat(p1): server executors + handlers + registrations

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Memory + roadmap update

**Files:**
- Modify: `~/.claude/projects/-Users-antonio-mcp-cline-mcp-flutter/memory/project_mcp_flutter_interaction_layer.md`
- Modify: `todo/playwright_parity_roadmap.md`

- [ ] **Step 1: Append a P1 section to the interaction-layer memory**

Mirror the wait_for section's shape: list the three new tools, the new error code, the Navigator-key registration API, anything subtle (key-event mapping, popup-route detection trick, etc.). Keep it under 25 lines.

- [ ] **Step 2: Mark P1 shipped in the roadmap**

In `todo/playwright_parity_roadmap.md`, update the P1 row:

```diff
-| **P1**   | Keyboard + dialog + navigate            | Small batch    | ...  |
+| **P1** ✅ | Keyboard + dialog + navigate *(shipped 2026-04-27)* | Small batch | ... |
```

- [ ] **Step 3: Commit**

```bash
cd /Users/antonio/mcp/cline/mcp_flutter && \
  git add todo/playwright_parity_roadmap.md && \
  git commit -m "docs(p1): mark P1 shipped in roadmap

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

(Memory file lives outside the repo; no commit needed — it's a personal note.)

---

## Self-review checklist

**1. Spec coverage.**
- press_key → Tasks 1, 3, 6
- handle_dialog (dismiss) → Tasks 1, 4, 6
- navigate → Tasks 1, 5, 6
- Navigator-key opt-in API → Task 2
- `navigator_not_registered` error code → Task 1, used by Tasks 4-6
- Memory + roadmap → Task 7

**2. No placeholders.** Every code step has actual code. The "verify the API" notes (e.g. step 3 of Task 4 about `popUntil` sentinel) are explicit "if you find this clever-by-half, look here" hints, not handwaves.

**3. Type consistency.** Names align: `press_key` / `pressKey` / `PressKeyCommand` / `pressKeyTool` / `pressKey` (handler) / `_pressKey` (executor) / `mcpToolkitExtKeys.pressKey` / `pressKeyFailed`. Same for `handle_dialog` and `navigate`.

**4. Branch.** Stays on `live-edit-v2-plannig` per the same instruction as P0.

**5. Roadmap link.** P1 in `todo/playwright_parity_roadmap.md` points here.

---

## Execution handoff

Plan saved to `docs/superpowers/plans/2026-04-27-p1-keyboard-dialog-navigate.md`. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review per task, fast iteration. Mirror the P0 flow.
2. **Inline Execution** — execute tasks in this session with checkpoints.

Defaulting to subagent-driven since P0 went well. The user said "P1 and continue" so proceeding without re-asking.
