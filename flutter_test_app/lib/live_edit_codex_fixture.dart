import 'package:flutter/material.dart';

class LiveEditCodexFixture extends StatelessWidget {
  const LiveEditCodexFixture({super.key});

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: const Color(0xFFFFF7ED),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Live Edit Maestro Fixture',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Semantics(
              identifier: 'live_edit_test_target',
              child: const Text(
                'Live Edit Test Target',
                semanticsIdentifier: 'live_edit_test_target_text',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use this deterministic target for live-edit integration coverage.',
            ),
          ],
        ),
      ),
    );
  }
}
