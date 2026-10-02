import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/visual_reconstruct_screen.dart';

void main() {
  testWidgets('visual reconstruct matches golden', (final tester) async {
    await tester.pumpWidget(const MaterialApp(home: VisualReconstructScreen()));
    await expectLater(
      find.byType(VisualReconstructScreen),
      matchesGoldenFile('goldens/visual_reconstruct.png'),
    );
  });
}
