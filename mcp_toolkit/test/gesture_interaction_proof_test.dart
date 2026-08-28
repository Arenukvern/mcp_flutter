import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

Future<Map<String, Object?>> _snapshotAfterPump(
  final WidgetTester tester,
) async {
  final snapshotFuture = SemanticSnapshotService.buildSemanticSnapshot();
  await tester.pump();
  await tester.pump();
  return snapshotFuture;
}

Future<T> _settleAfterPumps<T>(
  final WidgetTester tester,
  final Future<T> future, {
  final int pumps = 12,
}) async {
  for (var i = 0; i < pumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  return future;
}

String _refFor(final Map<String, Object?> snapshot, final String identifier) {
  final nodes = (snapshot['nodes']! as List<Object?>)
      .cast<Map<String, Object?>>();
  return nodes.firstWhere(
        (final node) => node['identifier'] == identifier,
      )['ref']!
      as String;
}

/// Swaps its child for a placeholder when [visible] is flipped through the
/// returned setter, so a snapshotted node can be taken out of the tree.
/// @ai Test-only fixture isolating a ref whose node leaves the tree.
class _Removable extends StatefulWidget {
  const _Removable({required this.child});

  final Widget child;

  @override
  State<_Removable> createState() => _RemovableState();
}

class _RemovableState extends State<_Removable> {
  static _RemovableState? current;
  bool visible = true;

  @override
  void initState() {
    super.initState();
    current = this;
  }

  void remove() => setState(() => visible = false);

  @override
  Widget build(final BuildContext context) =>
      visible ? widget.child : const SizedBox.shrink();
}

/// A scrolling header above the content list: the shape that makes "the first
/// scrollable in the tree" the wrong thing to scroll or to measure.
/// @ai Test-only fixture isolating ownership below a horizontal scroll strip.
class _StripAboveList extends StatelessWidget {
  const _StripAboveList();

  @override
  Widget build(final BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 30,
              itemBuilder: (final context, final index) =>
                  SizedBox(width: 120, child: Text('Chip $index')),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 60,
              itemBuilder: (final context, final index) => SizedBox(
                height: 48,
                child: Semantics(
                  identifier: 'row_$index',
                  child: Text('Row $index'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A scrolling side rail before the content list: both scroll vertically, so
/// "the first scrollable in the tree" and "the one the caller means" differ.
/// @ai Test-only fixture isolating competing vertical scrollables.
class _RailBesideList extends StatelessWidget {
  const _RailBesideList();

  @override
  Widget build(final BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Row(
        children: <Widget>[
          SizedBox(
            width: 120,
            child: ListView.builder(
              itemCount: 40,
              itemBuilder: (final context, final index) =>
                  SizedBox(height: 48, child: Text('Rail $index')),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 60,
              itemBuilder: (final context, final index) =>
                  SizedBox(height: 48, child: Text('Row $index')),
            ),
          ),
        ],
      ),
    ),
  );
}

/// An app shell: a navigation rail whose rows all stay in the tree while
/// scrolled out of view, beside a content list that occupies the screen centre.
/// Anything aimed at the centre drives the content, never the rail.
/// @ai Test-only fixture isolating centre-targeted scrolling in an app shell.
class _ShellRailBesideList extends StatelessWidget {
  const _ShellRailBesideList();

  @override
  Widget build(final BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Row(
        children: <Widget>[
          SizedBox(
            width: 120,
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  for (var i = 0; i < 40; i++)
                    SizedBox(
                      height: 48,
                      child: Semantics(
                        identifier: 'rail_$i',
                        label: 'Rail $i',
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 60,
              itemBuilder: (final context, final index) =>
                  SizedBox(height: 48, child: Text('Row $index')),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('a gesture refuses a ref whose node left the tree', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _Removable(
                child: Semantics(
                  identifier: 'doomed',
                  label: 'Doomed',
                  button: true,
                  onTap: () {},
                  child: const SizedBox(width: 120, height: 60),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ref = _refFor(await _snapshotAfterPump(tester), 'doomed');

      _RemovableState.current!.remove();
      await tester.pumpAndSettle();

      final tap = await _settleAfterPumps(
        tester,
        GestureInteractionService.tapAtRef(ref),
      );
      expect(tap['success'], isFalse);
      expect(tap['error'], 'stale_ref');
      expect(tap['via'], isNull, reason: 'no blind pointer tap may be sent');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('enter_text refuses a ref that is not a text field', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                Semantics(
                  identifier: 'expand',
                  label: 'Expand',
                  button: true,
                  onTap: () {},
                  child: const SizedBox(width: 60, height: 40),
                ),
                Semantics(
                  identifier: 'query',
                  child: SizedBox(
                    width: 300,
                    child: TextField(controller: controller),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = _refFor(await _snapshotAfterPump(tester), 'expand');

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.enterTextAtRef(button, 'wrong target'),
      );
      expect(result['success'], isFalse);
      expect(result['error'], 'not_a_text_field');
      expect(
        controller.text,
        isEmpty,
        reason: 'the only field on screen must not take the write',
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('enter_text into an unfocused field reports what landed', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                identifier: 'query',
                child: SizedBox(
                  width: 300,
                  child: TextField(controller: controller),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = _refFor(await _snapshotAfterPump(tester), 'query');
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
        isNot(isTrue),
      );

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.enterTextAtRef(field, 'typed blind'),
      );
      expect(result['success'], isTrue);
      expect(result['verified'], isTrue);
      expect(controller.text, 'typed blind');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('enter_text reports the value a formatter reshaped', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                identifier: 'days',
                child: SizedBox(
                  width: 300,
                  child: TextField(
                    controller: controller,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = _refFor(await _snapshotAfterPump(tester), 'days');

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.enterTextAtRef(field, '3 дня'),
      );
      // What a person typing there would get, so not a failure.
      expect(result['success'], isTrue);
      expect(result['verified'], isFalse);
      expect(result['appliedText'], '3');
      expect(controller.text, '3');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('enter_text clears a field when given an empty string', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = TextEditingController(text: 'to be cleared');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                identifier: 'query',
                child: SizedBox(
                  width: 300,
                  child: TextField(controller: controller),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = _refFor(await _snapshotAfterPump(tester), 'query');

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.enterTextAtRef(field, ''),
      );
      expect(result['success'], isTrue);
      expect(result['verified'], isTrue);
      expect(controller.text, isEmpty);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('enter_text fails when the field keeps nothing', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                identifier: 'digits',
                child: SizedBox(
                  width: 300,
                  child: TextField(
                    controller: controller,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = _refFor(await _snapshotAfterPump(tester), 'digits');

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.enterTextAtRef(field, 'abc'),
      );
      expect(result['success'], isFalse);
      expect(result['error'], 'text_not_applied');
      expect(result['appliedText'], isEmpty);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a gesture refuses a control that reports itself disabled', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                identifier: 'send',
                label: 'Send',
                button: true,
                enabled: false,
                child: const SizedBox(width: 120, height: 40),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ref = _refFor(await _snapshotAfterPump(tester), 'send');

      final tap = await _settleAfterPumps(
        tester,
        GestureInteractionService.tapAtRef(ref),
      );
      expect(tap['success'], isFalse);
      expect(tap['error'], 'target_disabled');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a rejected write puts back what the field held', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = TextEditingController(text: '7');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                identifier: 'digits',
                child: SizedBox(
                  width: 300,
                  child: TextField(
                    controller: controller,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = _refFor(await _snapshotAfterPump(tester), 'digits');

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.enterTextAtRef(field, 'abc'),
      );
      expect(result['success'], isFalse);
      expect(result['error'], 'text_not_applied');
      expect(
        controller.text,
        '7',
        reason: 'a refusal must not leave the field emptied',
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a swipe without measurable scroll reports unverified delivery', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var handled = false;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                identifier: 'custom_swipe',
                label: 'Custom swipe target',
                button: true,
                onTap: () {},
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerUp: (final _) => handled = true,
                  child: const SizedBox(width: 200, height: 200),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final target = _refFor(await _snapshotAfterPump(tester), 'custom_swipe');
      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.swipe(
          ref: target,
          direction: 'down',
          distance: 80,
        ),
        pumps: 20,
      );
      expect(handled, isTrue, reason: 'the target received the swipe input');
      expect(result['success'], isTrue);
      expect(result['verified'], isFalse);
      expect(result['measurementReason'], 'no_scrollable_at_point');
      expect(result['scrollBefore'], isNull);
      expect(result['scrollAfter'], isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a scroll reports the offsets of the list it actually moved', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const _StripAboveList());
      await tester.pumpAndSettle();

      final row = _refFor(await _snapshotAfterPump(tester), 'row_4');

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.scroll(
          ref: row,
          direction: 'down',
          distance: 200,
        ),
      );
      final positions = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .map((final s) => s.position.pixels)
          .toList();
      expect(result['success'], isTrue, reason: '$result');
      // The strip comes first in the tree and stays put; the list the row
      // belongs to is what moved, and the reported pair has to describe it.
      expect(positions.first, 0, reason: 'the header strip must stay put');
      expect(positions.last, greaterThan(0), reason: 'the row list must move');
      expect(result['scrollBefore'], 0.0);
      expect(result['scrollAfter'], positions.last);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a row ref scrolls the list that row belongs to', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const _ShellRailBesideList());
      await tester.pumpAndSettle();

      final row = _refFor(await _snapshotAfterPump(tester), 'rail_30');

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.scroll(
          ref: row,
          direction: 'down',
          distance: 200,
        ),
        pumps: 60,
      );
      final positions = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .map((final s) => s.position.pixels)
          .toList();

      expect(result['success'], isTrue, reason: '$result');
      // The row carries no scroll action of its own; the answer is its list.
      expect(positions.first, greaterThan(0), reason: 'the rail must move');
      expect(positions.last, 0, reason: 'the content list must stay put');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a list at its edge answers for itself, not for a stray point', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const _ShellRailBesideList());
      await tester.pumpAndSettle();

      // The rail starts at its top, so it drops scrollDown from its actions
      // and the row's own centre is far below the viewport.
      final row = _refFor(await _snapshotAfterPump(tester), 'rail_30');

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.scroll(
          ref: row,
          direction: 'up',
          distance: 200,
        ),
        pumps: 80,
      );

      expect(result['success'], isFalse);
      expect(
        result['error'],
        'no_scroll_movement',
        reason:
            'the rail is at its top; that is the answer, not "no '
            'scrollable under the point"',
      );
      expect(result['hint'], contains('start'));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('reveal_search scrolls the list its target lives in', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const _ShellRailBesideList());
      await tester.pumpAndSettle();

      final revealFuture = RevealSearchService.revealSearch(
        query: 'rail_20',
        matchBy: 'identifier',
        maxAttempts: 6,
        distance: 200,
      );
      for (var i = 0; i < 400; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final result = await revealFuture;
      final positions = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .map((final s) => s.position.pixels)
          .toList();

      expect(result['success'], isTrue, reason: '$result');
      expect(result['centerInViewport'], isTrue);
      expect(positions.first, greaterThan(0), reason: 'the rail is what moved');
      expect(
        positions.last,
        0,
        reason: 'scrolling the content would never reveal a rail row',
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a ref-less scroll drives the content, not the side rail', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const _RailBesideList());
      await tester.pumpAndSettle();
      await _snapshotAfterPump(tester);

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.scroll(direction: 'down', distance: 200),
      );
      final positions = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .map((final s) => s.position.pixels)
          .toList();

      expect(result['success'], isTrue, reason: '$result');
      expect(positions.first, 0, reason: 'the rail must stay where it was');
      expect(positions.last, greaterThan(0));
    } finally {
      semantics.dispose();
    }
  });
}
