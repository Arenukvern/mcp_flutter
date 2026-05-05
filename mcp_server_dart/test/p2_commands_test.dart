import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  final catalog = CommandCatalog.instance;

  group('FillFormCommand', () {
    test('round-trips fields and snapshotId', () {
      final cmd =
          catalog.buildCommand('fill_form', {
                'fields': <Map<String, Object?>>[
                  {'ref': 's_0', 'text': 'alice'},
                  {'ref': 's_1', 'text': 'bob'},
                ],
                'snapshotId': 42,
              })
              as FillFormCommand;
      expect(cmd.fields, hasLength(2));
      expect(cmd.fields[0]['ref'], 's_0');
      expect(cmd.fields[1]['text'], 'bob');
      expect(cmd.snapshotId, 42);
    });

    test('snapshotId null when omitted', () {
      final cmd =
          catalog.buildCommand('fill_form', {
                'fields': <Map<String, Object?>>[
                  {'ref': 's_0', 'text': 'x'},
                ],
              })
              as FillFormCommand;
      expect(cmd.snapshotId, isNull);
    });
  });

  group('HoverCommand', () {
    test('round-trips ref + snapshotId', () {
      final cmd =
          catalog.buildCommand('hover', {'ref': 's_3', 'snapshotId': 7})
              as HoverCommand;
      expect(cmd.ref, 's_3');
      expect(cmd.snapshotId, 7);
    });
  });
}
