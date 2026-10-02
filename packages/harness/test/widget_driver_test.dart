import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:test/test.dart';

/// Canned `semantic_snapshot` envelope: two labeled widgets, one of which
/// carries a selectable-text `value`.
Map<String, dynamic> _snapshotEnvelope() => {
      'data': {
        'nodes': [
          {'label': 'Pair…', 'ref': 's_0'},
          {'label': 'host pairing code', 'ref': 's_1'},
          {
            'label': 'my code',
            'ref': 's_2',
            'value': 'bWVzaC1wYWlyL3Yx-example-payload',
          },
        ],
      },
    };

void main() {
  group('WidgetDriver (canned extension responses)', () {
    test('snapshot returns (label, ref) pairs', () async {
      final calls = <String>[];
      final driver = WidgetDriver.custom((name, {args = const {}}) async {
        calls.add(name);
        return _snapshotEnvelope();
      });
      final snapshot = await driver.snapshot();
      expect(calls, [ToolkitExtensions.snapshot]);
      expect(snapshot, [
        ('Pair…', 's_0'),
        ('host pairing code', 's_1'),
        ('my code', 's_2'),
      ]);
    });

    test('tap routes the ref through the tap extension', () async {
      final calls = <(String, Map<String, Object?>)>[];
      final driver = WidgetDriver.custom((name, {args = const {}}) async {
        calls.add((name, args));
        return const <String, dynamic>{};
      });
      await driver.tap('s_0');
      expect(calls.single.$1, ToolkitExtensions.tap);
      expect(calls.single.$2, {'ref': 's_0'});
    });

    test('enterText routes ref and text through the enter extension',
        () async {
      final calls = <(String, Map<String, Object?>)>[];
      final driver = WidgetDriver.custom((name, {args = const {}}) async {
        calls.add((name, args));
        return const <String, dynamic>{};
      });
      await driver.enterText('s_1', 'secret');
      expect(calls.single.$1, ToolkitExtensions.enterText);
      expect(calls.single.$2, {'ref': 's_1', 'text': 'secret'});
    });

    test('findValue returns the first node value matching the predicate',
        () async {
      final driver = WidgetDriver.custom((name, {args = const {}}) async {
        return _snapshotEnvelope();
      });
      final value = await driver.findValue((v) => v.startsWith('bWVzaC1'));
      expect(value, 'bWVzaC1wYWlyL3Yx-example-payload');
      expect(await driver.findValue((v) => v.startsWith('nope')), isNull);
    });

    test('findRef matches case-insensitively', () async {
      final driver = WidgetDriver.custom((name, {args = const {}}) async {
        return _snapshotEnvelope();
      });
      expect(await driver.findRef('pair'), 's_0');
      expect(await driver.findRef('PAIRING'), 's_1');
    });
  });
}
