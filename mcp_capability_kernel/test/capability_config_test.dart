import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:test/test.dart';

void main() {
  group('CapabilityConfig', () {
    test('default constructor has empty values', () {
      const config = CapabilityConfig();
      expect(config.get<bool>('anything'), isNull);
      expect(config.getString('anything'), isNull);
      expect(config.getInt('anything'), isNull);
      expect(config.getBool('anything'), isFalse);
    });

    test('get<T> returns the value when type matches', () {
      const config = CapabilityConfig(
        values: {'enabled': true, 'count': 7, 'name': 'core'},
      );
      expect(config.get<bool>('enabled'), isTrue);
      expect(config.get<int>('count'), 7);
      expect(config.get<String>('name'), 'core');
    });

    test('get<T> returns null when type does not match', () {
      const config = CapabilityConfig(values: {'enabled': 'yes'});
      expect(config.get<bool>('enabled'), isNull);
    });

    test('get<T> returns null for missing key', () {
      const config = CapabilityConfig(values: {'enabled': true});
      expect(config.get<bool>('absent'), isNull);
    });

    test('getBool returns defaultValue when key missing', () {
      const config = CapabilityConfig();
      expect(config.getBool('missing'), isFalse);
      expect(config.getBool('missing', defaultValue: true), isTrue);
    });

    test('getBool returns defaultValue when value is wrong type', () {
      const config = CapabilityConfig(
        values: {'flag': 'true'},
      ); // String, not bool
      expect(config.getBool('flag'), isFalse);
      expect(config.getBool('flag', defaultValue: true), isTrue);
    });

    test('getString returns null for absent or wrong type', () {
      const config = CapabilityConfig(values: {'count': 7});
      expect(config.getString('count'), isNull);
      expect(config.getString('absent'), isNull);
    });

    test('getInt returns null for absent or wrong type', () {
      const config = CapabilityConfig(values: {'name': 'core'});
      expect(config.getInt('name'), isNull);
      expect(config.getInt('absent'), isNull);
    });
  });
}
