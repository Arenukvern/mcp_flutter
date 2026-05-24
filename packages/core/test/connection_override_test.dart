// packages/core/test/connection_override_test.dart
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:test/test.dart';

void main() {
  group('parseConnectionOverrideArguments', () {
    // 1. No override — arguments without `connection` key returns null/no-op.
    test('no connection key → no preconnect command, no error', () {
      final result = parseConnectionOverrideArguments(
        arguments: {'ref': 's_0', 'snapshotId': 42},
      );
      expect(result.error, isNull);
      expect(result.preconnectCommand, isNull);
      expect(result.connectionProvided, isFalse);
      expect(result.sanitizedArgs, equals({'ref': 's_0', 'snapshotId': 42}));
    });

    // 1b. Null arguments — treated as no override.
    test('null arguments → no preconnect command, no error', () {
      final result = parseConnectionOverrideArguments(arguments: null);
      expect(result.error, isNull);
      expect(result.preconnectCommand, isNull);
      expect(result.connectionProvided, isFalse);
    });

    // 2. Valid override — parses to ConnectionArgsResolution with expected fields.
    test(
      'valid connection {targetId, mode: auto} → parses to ConnectCommand',
      () {
        final result = parseConnectionOverrideArguments(
          arguments: {
            'ref': 's_0',
            'connection': {
              'targetId': 'ws://127.0.0.1:8181/token/ws',
              'mode': 'auto',
            },
          },
        );
        expect(result.error, isNull);
        expect(result.connectionProvided, isTrue);
        expect(
          result.sanitizedArgs.containsKey('connection'),
          isFalse,
          reason: 'connection key should be stripped from sanitizedArgs',
        );
        expect(result.sanitizedArgs['ref'], equals('s_0'));
        final cmd = result.preconnectCommand;
        expect(cmd, isNotNull);
        expect(cmd!.targetId, equals('ws://127.0.0.1:8181/token/ws'));
        expect(cmd.mode, equals(CoreConnectionMode.auto));
      },
    );

    test(
      'valid connection {mode: manual, host, port} → parses to ConnectCommand',
      () {
        final result = parseConnectionOverrideArguments(
          arguments: {
            'connection': {'mode': 'manual', 'host': 'localhost', 'port': 9999},
          },
        );
        expect(result.error, isNull);
        expect(result.connectionProvided, isTrue);
        final cmd = result.preconnectCommand;
        expect(cmd, isNotNull);
        expect(cmd!.mode, equals(CoreConnectionMode.manual));
        expect(cmd.host, equals('localhost'));
        expect(cmd.port, equals(9999));
      },
    );

    test('valid connection {mode: uri, uri} → parses to ConnectCommand', () {
      final result = parseConnectionOverrideArguments(
        arguments: {
          'connection': {'mode': 'uri', 'uri': 'ws://127.0.0.1:8181/token/ws'},
        },
      );
      expect(result.error, isNull);
      final cmd = result.preconnectCommand;
      expect(cmd, isNotNull);
      expect(cmd!.mode, equals(CoreConnectionMode.uri));
      expect(cmd.uri, equals('ws://127.0.0.1:8181/token/ws'));
    });

    // 3. Connection not an object — produces a structured error.
    test('connection: "string" → structured error', () {
      final result = parseConnectionOverrideArguments(
        arguments: {'connection': 'not-an-object'},
      );
      expect(result.error, isNotNull);
      expect(result.error!.ok, isFalse);
      expect(result.error!.error?.code, equals(CoreErrorCode.invalidCommand));
      expect(result.connectionProvided, isTrue);
    });

    test('connection: 42 → structured error', () {
      final result = parseConnectionOverrideArguments(
        arguments: {'connection': 42},
      );
      expect(result.error, isNotNull);
      expect(result.error!.error?.code, equals(CoreErrorCode.invalidCommand));
    });

    // 4. Unknown field — rejected.
    test(
      'connection with unknown field → structured error naming the field',
      () {
        final result = parseConnectionOverrideArguments(
          arguments: {
            'connection': {
              'targetId': 'ws://127.0.0.1:8181/token/ws',
              'bogus': true,
            },
          },
        );
        expect(result.error, isNotNull);
        expect(result.error!.error?.code, equals(CoreErrorCode.invalidCommand));
        final msg = result.error!.error?.message ?? '';
        expect(msg, contains('bogus'));
      },
    );

    // 5. Negative port — rejected.
    test('connection with port: -1 → structured error', () {
      final result = parseConnectionOverrideArguments(
        arguments: {
          'connection': {'port': -1},
        },
      );
      expect(result.error, isNotNull);
      expect(result.error!.error?.code, equals(CoreErrorCode.invalidCommand));
    });

    test('connection with port: 0 → structured error (not positive)', () {
      final result = parseConnectionOverrideArguments(
        arguments: {
          'connection': {'port': 0},
        },
      );
      expect(result.error, isNotNull);
      expect(result.error!.error?.code, equals(CoreErrorCode.invalidCommand));
    });

    // 6. Mode out of enum — rejected.
    test('connection.mode: "galaxy" → structured error', () {
      final result = parseConnectionOverrideArguments(
        arguments: {
          'connection': {'mode': 'galaxy'},
        },
      );
      expect(result.error, isNotNull);
      expect(result.error!.error?.code, equals(CoreErrorCode.invalidCommand));
    });

    // 7. forceReconnect type error — string instead of bool rejected.
    test('connection.forceReconnect: "yes" (string) → structured error', () {
      final result = parseConnectionOverrideArguments(
        arguments: {
          'connection': {'forceReconnect': 'yes'},
        },
      );
      expect(result.error, isNotNull);
      expect(result.error!.error?.code, equals(CoreErrorCode.invalidCommand));
    });

    test('connection.forceReconnect: 1 (int) → structured error', () {
      final result = parseConnectionOverrideArguments(
        arguments: {
          'connection': {'forceReconnect': 1},
        },
      );
      expect(result.error, isNotNull);
      expect(result.error!.error?.code, equals(CoreErrorCode.invalidCommand));
    });

    // Valid forceReconnect: true — should work.
    test('connection.forceReconnect: true → accepted', () {
      final result = parseConnectionOverrideArguments(
        arguments: {
          'connection': {
            'targetId': 'ws://127.0.0.1:8181/token/ws',
            'forceReconnect': true,
          },
        },
      );
      expect(result.error, isNull);
      expect(result.preconnectCommand?.forceReconnect, isTrue);
    });

    // 8. Selector command conflict path (via resolveCommandArgumentsForExecution).
    // 'connect' is a selector command; providing both connection override AND
    // a native selector field in the top-level args is a conflict.
    test(
      'resolveCommandArgumentsForExecution: selector command + connection + native field → conflict error',
      () {
        // 'connect' is a selector command; 'mode' is a native selector field.
        final result = resolveCommandArgumentsForExecution(
          commandName: 'connect',
          arguments: {
            'mode': 'auto',
            'connection': {'targetId': 'ws://127.0.0.1:8181/token/ws'},
          },
        );
        expect(result.error, isNotNull);
        expect(result.error!.error?.code, equals(CoreErrorCode.invalidCommand));
        final msg = result.error!.error?.message ?? '';
        expect(msg, contains('native selector field'));
      },
    );

    // Non-selector command with legacy flat field → error.
    test(
      'resolveCommandArgumentsForExecution: non-selector command with legacy field → error',
      () {
        final result = resolveCommandArgumentsForExecution(
          commandName: 'tap_widget',
          arguments: {'ref': 's_0', 'host': 'localhost'},
        );
        expect(result.error, isNotNull);
        expect(result.error!.error?.code, equals(CoreErrorCode.invalidCommand));
        final msg = result.error!.error?.message ?? '';
        expect(msg, contains('host'));
      },
    );

    // fallbackToAuto: true → preconnectCommand produced even without connection key.
    test(
      'fallbackToAuto: true → produces auto ConnectCommand when no connection key',
      () {
        final result = parseConnectionOverrideArguments(
          arguments: {'ref': 's_0'},
          fallbackToAuto: true,
        );
        expect(result.error, isNull);
        expect(result.preconnectCommand, isNotNull);
        expect(result.preconnectCommand!.mode, equals(CoreConnectionMode.auto));
      },
    );
  });
}
