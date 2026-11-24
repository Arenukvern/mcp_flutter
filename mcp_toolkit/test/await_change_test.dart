import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/src/services/await_change.dart';

void main() {
  testWidgets(
    'awaitChange returns settled false and delta when change did not settle',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _ChatReplyFixture())),
      );
      await tester.pump();

      final awaitFuture = runWithAwaitChange(
        const <String, Object?>{'settleMs': 2000, 'timeoutMs': 800},
        () async {},
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final result = await awaitFuture;

      expect(result['settled'], isFalse);
      expect(result['changeBaselineId'], isA<int>());
      expect(result['delta'], isA<String>());
      expect(result['delta'], isNot('# no change'));
      expect(result.containsKey('changeWait'), isFalse);
    },
  );
}

class _ChatReplyFixture extends StatefulWidget {
  const _ChatReplyFixture();

  @override
  State<_ChatReplyFixture> createState() => _ChatReplyFixtureState();
}

class _ChatReplyFixtureState extends State<_ChatReplyFixture> {
  bool _showReply = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _showReply = true);
    });
  }

  @override
  Widget build(BuildContext context) => Center(
    child: _showReply
        ? Semantics(
            label: "14:20\nI'm here and ready when you are.",
            child: const SizedBox(width: 200, height: 40),
          )
        : const Text('Waiting…'),
  );
}