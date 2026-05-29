import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/dynamic_registry/dynamic_gateway.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/error_codes.dart';
import 'package:test/test.dart';

void main() {
  group('validationFailureForDynamicSchema', () {
    test('rejects resource read without uri when schema requires uri', () {
      final failure = validationFailureForDynamicSchema(
        subjectLabel: 'resource "visual://test"',
        schema: clientResourceReadInputSchema(),
        arguments: const <String, Object?>{},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('accepts resource read with uri', () {
      final failure = validationFailureForDynamicSchema(
        subjectLabel: 'resource "visual://test"',
        schema: clientResourceReadInputSchema(),
        arguments: const <String, Object?>{'uri': 'visual://test'},
      );

      expect(failure, isNull);
    });

    test('fail-closed when tool schema missing from listing', () {
      final failure = validationFailureForDynamicSchema(
        subjectLabel: 'tool "tap_widget"',
        schema: null,
        arguments: const <String, Object?>{'ref': 's_0'},
      );

      expect(failure, isNotNull);
      expect(failure!.error!.message, contains('inputSchema missing'));
    });

    test('rejects tap_widget args missing ref', () {
      final failure = validationFailureForDynamicSchema(
        subjectLabel: 'tool "tap_widget"',
        schema: tapWidgetInputSchema(),
        arguments: const <String, Object?>{},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
    });

    test('coerces wire integer strings before validate', () {
      final failure = validationFailureForDynamicSchema(
        subjectLabel: 'tool "tap_widget"',
        schema: tapWidgetInputSchema(),
        arguments: const <String, Object?>{
          'ref': 's_0',
          'snapshotId': '42',
        },
      );

      expect(failure, isNull);
    });

    test('raw validate rejects integer wire strings without coercion', () {
      expect(
        () => validateAgainstSchema(
          tapWidgetInputSchema(),
          const <String, Object?>{
            'ref': 's_0',
            'snapshotId': '42',
          },
        ),
        throwsA(isA<AgentValidationException>()),
      );
    });
  });
}
