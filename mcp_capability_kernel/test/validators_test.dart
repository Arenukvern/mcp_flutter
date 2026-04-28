// mcp_capability_kernel/test/validators_test.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:test/test.dart';

void main() {
  group('validateCapabilityId', () {
    test('accepts lowercase alphanumeric with underscores', () {
      validateCapabilityId('core');
      validateCapabilityId('live_edit');
      validateCapabilityId('a');
      validateCapabilityId('a1');
      validateCapabilityId('snake_case_123');
    });

    test('rejects empty', () {
      expect(
        () => validateCapabilityId(''),
        throwsA(isA<InvalidCapabilityIdError>()),
      );
    });

    test('rejects leading digit', () {
      expect(
        () => validateCapabilityId('1foo'),
        throwsA(isA<InvalidCapabilityIdError>()),
      );
    });

    test('rejects uppercase', () {
      expect(
        () => validateCapabilityId('LiveEdit'),
        throwsA(isA<InvalidCapabilityIdError>()),
      );
    });

    test('rejects hyphen and dot', () {
      expect(
        () => validateCapabilityId('live-edit'),
        throwsA(isA<InvalidCapabilityIdError>()),
      );
      expect(
        () => validateCapabilityId('live.edit'),
        throwsA(isA<InvalidCapabilityIdError>()),
      );
    });

    test('rejects reserved id "app"', () {
      expect(
        () => validateCapabilityId('app'),
        throwsA(isA<InvalidCapabilityIdError>()),
      );
    });
  });

  group('validateBareToolName', () {
    test('accepts a name that does not start with the capability prefix', () {
      validateBareToolName(capabilityId: 'core', name: 'tap_widget');
      validateBareToolName(capabilityId: 'live_edit', name: 'select');
    });

    test('rejects a name that starts with the capability prefix', () {
      expect(
        () =>
            validateBareToolName(capabilityId: 'core', name: 'core_tap_widget'),
        throwsA(isA<PrePrefixedToolNameError>()),
      );
      expect(
        () => validateBareToolName(
          capabilityId: 'live_edit',
          name: 'live_edit_select',
        ),
        throwsA(isA<PrePrefixedToolNameError>()),
      );
    });

    test('accepts coincidental prefix-suffix overlap', () {
      // 'core_thing' from a capability with id 'foo' — fine, prefix is 'foo_'
      validateBareToolName(capabilityId: 'foo', name: 'core_thing');
    });
  });

  group('applyPrefix', () {
    test('joins capability id and bare name with underscore', () {
      expect(
        applyPrefix(capabilityId: 'core', name: 'tap_widget'),
        'core_tap_widget',
      );
      expect(
        applyPrefix(capabilityId: 'live_edit', name: 'select'),
        'live_edit_select',
      );
    });
  });
}
