import 'package:flutter/gestures.dart';
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

/// A board scrolling sideways whose cards are dragged by a pan gesture. Those
/// cards publish scrollLeft / scrollRight of their own — Flutter mirrors a pan
/// handler into scroll semantics — while only the board can actually scroll.
/// @ai Test-only fixture isolating a draggable that advertises scroll actions.
class _DragBoard extends StatelessWidget {
  const _DragBoard();

  static final List<String> dragged = <String>[];

  @override
  Widget build(final BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < 12; i++)
              MergeSemantics(
                child: Semantics(
                  identifier: 'card_$i',
                  label: 'Card $i',
                  child: GestureDetector(
                    onPanStart: (final _) => dragged.add('card_$i'),
                    onPanUpdate: (final _) {},
                    onPanEnd: (final _) {},
                    child: const SizedBox(width: 260, height: 140),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// A card too short to survive a coarse drag: 29 px tall, with a long-press
/// recognizer beside the pan so the arena cannot hand the pan over at
/// pointer-down. The shape of a calendar block, whose outer 8 px resize the
/// event and whose middle moves it.
/// @ai Test-only fixture isolating the press point a drag reports.
class _ShortCardBoard extends StatelessWidget {
  const _ShortCardBoard({required this.onDragStart});

  final ValueChanged<DragStartDetails> onDragStart;

  @override
  Widget build(final BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned(
            left: 40,
            top: 40,
            child: Semantics(
              identifier: 'short_card',
              label: 'Card',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: onDragStart,
                onPanUpdate: (final _) {},
                onPanEnd: (final _) {},
                onLongPressStart: (final _) {},
                child: const SizedBox(width: 200, height: 29),
              ),
            ),
          ),
          Positioned(
            left: 500,
            top: 300,
            child: Semantics(
              identifier: 'drop_slot',
              label: 'Slot',
              child: const SizedBox(width: 200, height: 29),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('a drag reports the press point, not the pointer it ran on', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      DragStartDetails? start;
      await tester.pumpWidget(
        _ShortCardBoard(onDragStart: (final details) => start = details),
      );
      await tester.pumpAndSettle();

      final snapshot = await _snapshotAfterPump(tester);
      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.drag(
          fromRef: _refFor(snapshot, 'short_card'),
          toRef: _refFor(snapshot, 'drop_slot'),
          kind: PointerDeviceKind.mouse,
        ),
        pumps: 90,
      );

      expect(result['success'], isTrue);
      final press = start!.localPosition.dy;
      expect(
        press,
        inExclusiveRange(8, 21),
        reason: 'the drag began in the resize edge the pointer never pressed',
      );
    } finally {
      semantics.dispose();
    }
  });

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

      final focus = await _settleAfterPumps(
        tester,
        GestureInteractionService.focusAtRef(ref),
      );
      expect(focus['success'], isFalse);
      expect(focus['error'], 'target_disabled');
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

  testWidgets('a draggable card ref scrolls the board, never itself', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    _DragBoard.dragged.clear();
    try {
      await tester.pumpWidget(const _DragBoard());
      await tester.pumpAndSettle();

      final card = _refFor(await _snapshotAfterPump(tester), 'card_6');

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.scroll(
          ref: card,
          direction: 'right',
          distance: 200,
        ),
        pumps: 60,
      );
      final board = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;

      expect(result['success'], isTrue, reason: '$result');
      expect(board, greaterThan(0), reason: 'the board must move');
      expect(
        _DragBoard.dragged,
        isEmpty,
        reason: 'a scroll must not pick the card up',
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('custom scroll semantics without geometry still take the action', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var handled = 0;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                identifier: 'canvas',
                onScrollUp: () => handled++,
                child: const SizedBox(width: 300, height: 300),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final canvas = _refFor(await _snapshotAfterPump(tester), 'canvas');

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.scroll(
          ref: canvas,
          direction: 'down',
          distance: 200,
        ),
        pumps: 30,
      );

      expect(result['success'], isTrue, reason: '$result');
      expect(result['via'], 'semantic_action');
      expect(result['verified'], isFalse);
      expect(result['unmeasured'], isTrue);
      expect(handled, 1, reason: 'the handler must run exactly once');
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

  testWidgets('focus lands through the semantic action and is proven', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final target = FocusNode(debugLabel: 'target');
      final other = FocusNode(debugLabel: 'other');
      addTearDown(target.dispose);
      addTearDown(other.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                Semantics(
                  container: true,
                  identifier: 'other',
                  label: 'Other',
                  child: Focus(
                    focusNode: other,
                    autofocus: true,
                    child: const SizedBox(width: 120, height: 40),
                  ),
                ),
                Semantics(
                  container: true,
                  identifier: 'target',
                  label: 'Target',
                  child: Focus(
                    focusNode: target,
                    child: const SizedBox(width: 120, height: 40),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(other.hasPrimaryFocus, isTrue);

      final snapshot = await _snapshotAfterPump(tester);
      final ref = _refFor(snapshot, 'target');
      final node = (snapshot['nodes']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .firstWhere((final n) => n['ref'] == ref);
      expect(node['actions'], contains('focus'));

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.focusAtRef(ref),
      );
      expect(result['success'], isTrue);
      expect(result['via'], 'semantic_action');
      expect(result['verified'], isTrue);
      expect(result['verifiedBy'], 'semantics_flag');
      expect(result['focusMoved'], isTrue);
      expect(target.hasPrimaryFocus, isTrue);
      expect(other.hasPrimaryFocus, isFalse);

      // A second call finds focus already there and says so.
      final again = await _settleAfterPumps(
        tester,
        GestureInteractionService.focusAtRef(ref),
      );
      expect(again['success'], isTrue);
      expect(again['focusMoved'], isFalse);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('focus opens a text field for the keystrokes that follow', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final focusNode = FocusNode(debugLabel: 'query');
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                identifier: 'query',
                child: SizedBox(
                  width: 300,
                  child: TextField(focusNode: focusNode),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isFalse);

      final ref = _refFor(await _snapshotAfterPump(tester), 'query');
      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.focusAtRef(ref),
      );
      expect(result['success'], isTrue);
      expect(result['verified'], isTrue);
      expect(focusNode.hasPrimaryFocus, isTrue);

      // The field now advertises setText: the semantic route enter_text
      // prefers is open.
      final after = await _snapshotAfterPump(tester);
      final node = (after['nodes']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .firstWhere((final n) => n['identifier'] == 'query');
      expect(node['focused'], isTrue);
      expect(node['actions'], contains('setText'));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('focus reaches a focus node its semantics keep quiet about', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final target = FocusNode(debugLabel: 'target');
      addTearDown(target.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                container: true,
                identifier: 'target',
                label: 'Target',
                child: Focus(
                  focusNode: target,
                  includeSemantics: false,
                  child: const SizedBox(width: 120, height: 40),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final snapshot = await _snapshotAfterPump(tester);
      final ref = _refFor(snapshot, 'target');
      final node = (snapshot['nodes']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .firstWhere((final n) => n['ref'] == ref);
      expect(node['actions'] ?? const <String>[], isNot(contains('focus')));

      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.focusAtRef(ref),
      );
      expect(result['success'], isTrue);
      expect(result['via'], 'focus_node');
      expect(result['verifiedBy'], 'focus_node');
      expect(target.hasPrimaryFocus, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('focus refuses a node with nothing focusable behind it', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                container: true,
                identifier: 'caption',
                label: 'Just a caption',
                child: const SizedBox(width: 120, height: 40),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ref = _refFor(await _snapshotAfterPump(tester), 'caption');
      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.focusAtRef(ref),
      );
      expect(result['success'], isFalse);
      expect(result['error'], 'focus_not_exposed');
      expect(result['hint'], isA<String>());
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('focus names the node that took it away from the target', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final target = FocusNode(debugLabel: 'target');
      final thief = FocusNode(debugLabel: 'thief');
      addTearDown(target.dispose);
      addTearDown(thief.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                Semantics(
                  container: true,
                  identifier: 'target',
                  label: 'Target',
                  child: Focus(
                    focusNode: target,
                    // A handler that passes focus on as soon as it arrives.
                    onFocusChange: (final hasFocus) {
                      if (hasFocus) thief.requestFocus();
                    },
                    child: const SizedBox(width: 120, height: 40),
                  ),
                ),
                Semantics(
                  container: true,
                  identifier: 'thief',
                  label: 'Thief',
                  child: Focus(
                    focusNode: thief,
                    child: const SizedBox(width: 120, height: 40),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ref = _refFor(await _snapshotAfterPump(tester), 'target');
      final result = await _settleAfterPumps(
        tester,
        GestureInteractionService.focusAtRef(ref),
      );
      expect(result['success'], isFalse);
      expect(result['error'], 'focus_refused');
      expect(result['via'], 'semantic_action');
      final focusedNow = result['focusedNow']! as Map<String, Object?>;
      expect(focusedNow['identifier'], 'thief');
      expect(result['hint'], contains('Thief'));
      expect(thief.hasPrimaryFocus, isTrue);
    } finally {
      semantics.dispose();
    }
  });
}
