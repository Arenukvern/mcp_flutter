import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

/// The ADR 0052 vmService rung: the toolkit's snapshot projects into
/// the automation family's Snapshot/Observation, so `render` and
/// `delta` speak the same grammar the OS/CDP tiers speak — while the
/// `nodes` envelope and interaction-by-ref stay untouched.
void main() {
  Future<Map<String, Object?>> snapshotAfterPump(
    WidgetTester tester, {
    bool render = false,
    bool diff = false,
  }) async {
    final future = SemanticSnapshotService.buildSemanticSnapshot(
      render: render,
      diff: diff,
    );
    await tester.pump();
    await tester.pump();
    return future;
  }

  Widget tree({String label = 'Go'}) => MaterialApp(
    home: Scaffold(
      body: Semantics(
        identifier: 'primary_go_button',
        button: true,
        label: label,
        child: const SizedBox(width: 40, height: 40),
      ),
    ),
  );

  testWidgets('render speaks the family observation grammar', (
    tester,
  ) async {
    await tester.pumpWidget(tree());
    await tester.pumpAndSettle();

    final snapshot = await snapshotAfterPump(tester, render: true);
    final renderText = snapshot['render']! as String;
    expect(renderText, startsWith('# observation'));
    expect(renderText, contains('button "Go"'));
    // Refs agree with the nodes list: family refs are positional over
    // the same emitted walk.
    final nodes = snapshot['nodes']! as List<Object?>;
    final go = nodes.cast<Map<String, Object?>>().singleWhere(
      (node) => node['label'] == 'Go',
    );
    expect(renderText, contains('${go['ref']} button "Go"'));
    // Without the flag, the envelope stays lean.
    final plain = await snapshotAfterPump(tester);
    expect(plain.containsKey('render'), isFalse);
  });

  testWidgets('diff reports no change for an unchanged surface', (
    tester,
  ) async {
    await tester.pumpWidget(tree());
    await tester.pumpAndSettle();
    await snapshotAfterPump(tester);
    // Settle the previous call's microtasks so the id stream advances,
    // then diff against it over the identical tree.
    await tester.pump();

    final second = await snapshotAfterPump(tester, diff: true);
    expect(second['delta'], '# no change');
  });

  testWidgets('diff reports an added control as a + row', (tester) async {
    await tester.pumpWidget(tree());
    await tester.pumpAndSettle();
    await snapshotAfterPump(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Semantics(
                identifier: 'primary_go_button',
                button: true,
                label: 'Go',
                child: const SizedBox(width: 40, height: 40),
              ),
              Semantics(
                identifier: 'secondary_cancel_button',
                button: true,
                label: 'Cancel',
                child: const SizedBox(width: 40, height: 40),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final second = await snapshotAfterPump(tester, diff: true);
    final delta = second['delta']! as String;
    expect(delta, isNot('# no change'));
    expect(delta, contains('+ '));
    expect(delta, contains('"Cancel"'));
  });
}
