import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Policy (5a): only auto/bootstrap files may import `flutter_live_edit_agent`.
void main() {
  test('flutter_live_edit_agent imports are confined to auto wiring', () {
    final libRoot = Directory('lib');
    expect(libRoot.existsSync(), isTrue);

    const allowed = <String>{
      'lib/src/live_edit_auto.dart',
      'lib/src/live_edit_auto_delegate.dart',
    };

    final violations = <String>[];
    final cwd = Directory.current.path;
    for (final entity in libRoot.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final normalized = p.normalize(p.relative(entity.path, from: cwd));
      final text = entity.readAsStringSync();
      if (text.contains("import 'package:flutter_live_edit_agent/") ||
          text.contains('import "package:flutter_live_edit_agent/')) {
        if (!allowed.contains(normalized)) {
          violations.add(normalized);
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Move agent usage into $allowed or update this test.',
    );
  });
}
