import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  // -----------------------------------------------------------------------
  // press_key
  // -----------------------------------------------------------------------

  testWidgets(
    'press_key Enter is observed by the focused Focus widget',
    (final tester) async {
      // NOTE: We assert against `Focus.onKeyEvent`, not `TextField.onSubmitted`.
      // TextField submission travels via the `flutter/textinput` channel
      // (`TextInputAction.done`), not raw key events — synthesized hardware
      // keys are by design unreachable to onSubmitted. press_key is for the
      // focus-tree path: Focus/Shortcuts/Actions/Tab traversal.
      var gotEnter = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Focus(
              autofocus: true,
              onKeyEvent: (final node, final event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  gotEnter = true;
                }
                return KeyEventResult.ignored;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = await ControlFlowService.pressKey(key: 'Enter');
      await tester.pump();

      expect(result['success'], isTrue);
      expect(result['key'], 'Enter');
      expect(gotEnter, isTrue);
    },
  );

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

  testWidgets(
    'press_key Ctrl+S dispatches a Shortcuts/Intent/Action handler',
    (final tester) async {
      // Validates the two-pass dispatch (HardwareKeyboard.handleKeyEvent +
      // KeyEventManager.keyMessageHandler) for a modifier+key combo. A
      // chord goes through the Shortcuts → Intent → Action pipeline
      // installed at the top of the focus tree by the Shortcuts widget.
      var saveInvoked = 0;
      final saveIntent = const _SaveIntent();
      await tester.pumpWidget(
        MaterialApp(
          home: Shortcuts(
            shortcuts: <ShortcutActivator, Intent>{
              const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                  saveIntent,
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                _SaveIntent: CallbackAction<_SaveIntent>(
                  onInvoke: (final _) {
                    saveInvoked++;
                    return null;
                  },
                ),
              },
              child: Focus(
                autofocus: true,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result =
          await ControlFlowService.pressKey(key: 's', ctrl: true);
      await tester.pump();

      expect(result['success'], isTrue);
      expect(result['ctrl'], isTrue);
      expect(saveInvoked, 1);
    },
  );

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

  testWidgets(
    'navigate popUntil rejects a route not in the stack instead of '
    'popping everything',
    (final tester) async {
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

      final result = await ControlFlowService.navigate(
        action: 'popUntil',
        route: '/does_not_exist',
      );
      await tester.pumpAndSettle();

      expect(result['success'], isFalse);
      expect(result['error'], 'route_not_in_stack');
      expect(result['route'], '/does_not_exist');
      expect(result['currentRoutes'], isA<List<Object?>>());
      // Both routes must still be on the stack — nothing was popped.
      expect(find.text('inner page'), findsOneWidget);

      MCPToolkitBinding.instance.setNavigatorKey(null);
    },
  );

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

    // Parallel-pump: buildSemanticSnapshot awaits binding.endOfFrame (cold
    // path under the test binding), and hoverAtRef awaits Future.delayed
    // via _waitFrame. Both need pumps to advance — kick off the future,
    // drive frames, collect.
    final snapshotFuture = SemanticSnapshotService.buildSemanticSnapshot();
    await tester.pump();
    await tester.pump();
    final snapshot = await snapshotFuture;
    final nodes = snapshot['nodes']! as List<Object?>;
    // Find the ref whose label is 'hover_target'.
    final targetEntry = nodes.firstWhere(
      (final n) =>
          (n is Map && (n['label'] as String?)?.contains('hover_target') == true),
    ) as Map<Object?, Object?>;
    final ref = targetEntry['ref']! as String;

    final hoverFuture = GestureInteractionService.hoverAtRef(ref);
    // _waitFrame is Future.delayed(16ms); pump past it.
    await tester.pump(const Duration(milliseconds: 20));
    final result = await hoverFuture;
    // MouseTracker schedules onEnter via SchedulerBinding.postFrameCallback;
    // those run during the frame after they were scheduled, so pump
    // multiple times to be safe.
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(result['success'], isTrue);
    expect(entered, isTrue);
  });

  testWidgets('hover returns ref_not_found for an unknown ref',
      (final tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pumpAndSettle();

    // _refNotFound short-circuits before any timer, so no runAsync needed.
    final result =
        await GestureInteractionService.hoverAtRef('s_does_not_exist');
    expect(result['success'], isFalse);
    // _refNotFound returns a human-readable message containing 'not found'
    // rather than a token like 'ref_not_found' — match the existing shape.
    expect(result['error'], contains('not found'));
  });
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}
