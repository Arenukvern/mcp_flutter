import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/commands/commands_catalog.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/commands/interaction_catalog_validation.dart';
import 'package:test/test.dart';

void main() {
  group('validationFailureForInteractionCatalogCommand', () {
    test('rejects tap_widget missing ref', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'tap_widget',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('accepts tap_widget with ref', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'tap_widget',
        arguments: const <String, Object?>{'ref': 's_0'},
      );

      expect(failure, isNull);
    });

    test('rejects fill_form missing fields', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'fill_form',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
      expect(failure.error!.message, contains('fields'));
    });

    test('accepts fill_form with fields', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'fill_form',
        arguments: const <String, Object?>{
          'fields': <Map<String, Object?>>[
            {'ref': 's_0', 'text': 'alice'},
          ],
        },
      );

      expect(failure, isNull);
    });

    test('rejects fill_form fields item missing ref and text', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'fill_form',
        arguments: const <String, Object?>{
          'fields': <Map<String, Object?>>[{}],
        },
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
      expect(failure.error!.message, contains('ref'));
    });

    test('rejects fill_form fields item missing ref', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'fill_form',
        arguments: const <String, Object?>{
          'fields': <Map<String, Object?>>[
            {'text': 'x'},
          ],
        },
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
      expect(failure.error!.message, contains('ref'));
    });

    test('rejects fill_form unknown keys', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'fill_form',
        arguments: const <String, Object?>{
          'fields': <Map<String, Object?>>[
            {'ref': 's_0', 'text': 'alice'},
          ],
          'unexpected': true,
        },
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('ignores non-interaction catalog commands', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'status',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNull);
    });

    test('rejects wait_for timeoutMs below minimum', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'wait_for',
        arguments: const <String, Object?>{
          'predicate': <String, Object?>{'kind': 'time', 'ms': 1},
          'timeoutMs': 0,
        },
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
      expect(failure.error!.message, contains('timeoutMs'));
    });

    test('rejects wait_for timeoutMs above maximum', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'wait_for',
        arguments: const <String, Object?>{
          'predicate': <String, Object?>{'kind': 'time', 'ms': 1},
          'timeoutMs': 30001,
        },
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.message, contains('30000'));
    });

    test('accepts wait_for timeoutMs within bounds', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'wait_for',
        arguments: const <String, Object?>{
          'predicate': <String, Object?>{'kind': 'time', 'ms': 1},
          'timeoutMs': 8000,
        },
      );

      expect(failure, isNull);
    });

    test('rejects handle_dialog missing action', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'handle_dialog',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('accepts handle_dialog with action', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'handle_dialog',
        arguments: const <String, Object?>{'action': 'dismiss'},
      );

      expect(failure, isNull);
    });

    test('rejects navigate missing action', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'navigate',
        arguments: const <String, Object?>{'route': '/settings'},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('accepts navigate with action', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'navigate',
        arguments: const <String, Object?>{'action': 'push', 'route': '/x'},
      );

      expect(failure, isNull);
    });

    test('accepts get_recent_logs with empty args', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'get_recent_logs',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNull);
    });

    test('rejects get_recent_logs unknown keys', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'get_recent_logs',
        arguments: const <String, Object?>{'unexpected': true},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('rejects evaluate_dart_expression missing expression', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'evaluate_dart_expression',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('accepts evaluate_dart_expression with expression', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'evaluate_dart_expression',
        arguments: const <String, Object?>{'expression': 'true'},
      );

      expect(failure, isNull);
    });

    test('accepts hot_reload_and_capture with empty args', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'hot_reload_and_capture',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNull);
    });

    test('rejects hot_reload_and_capture unknown keys', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'hot_reload_and_capture',
        arguments: const <String, Object?>{'unexpected': true},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('accepts hot_reload_flutter with empty args', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'hot_reload_flutter',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNull);
    });

    test('accepts hot_reload_flutter with force', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'hot_reload_flutter',
        arguments: const <String, Object?>{'force': true},
      );

      expect(failure, isNull);
    });

    test('rejects hot_reload_flutter unknown keys', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'hot_reload_flutter',
        arguments: const <String, Object?>{'unexpected': true},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('accepts hot_restart_flutter with empty args', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'hot_restart_flutter',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNull);
    });

    test('rejects hot_restart_flutter unknown keys', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'hot_restart_flutter',
        arguments: const <String, Object?>{'unexpected': true},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('accepts get_screenshots with empty args', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'get_screenshots',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNull);
    });

    test('rejects get_screenshots unknown keys', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'get_screenshots',
        arguments: const <String, Object?>{'unexpected': true},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('accepts capture_ui_snapshot with empty args', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'capture_ui_snapshot',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNull);
    });

    test('rejects capture_ui_snapshot unknown keys', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'capture_ui_snapshot',
        arguments: const <String, Object?>{'unexpected': true},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('rejects inspect_widget_at_point missing x and y', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'inspect_widget_at_point',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('accepts inspect_widget_at_point with x and y', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'inspect_widget_at_point',
        arguments: const <String, Object?>{'x': 0, 'y': 0},
      );

      expect(failure, isNull);
    });

    test('accepts get_view_details with empty args', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'get_view_details',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNull);
    });

    test('rejects get_view_details unknown keys', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'get_view_details',
        arguments: const <String, Object?>{'unexpected': true},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('accepts get_app_errors with empty args', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'get_app_errors',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNull);
    });

    test('rejects get_app_errors unknown keys', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'get_app_errors',
        arguments: const <String, Object?>{'unexpected': true},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('accepts focus_window with empty args', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'focus_window',
        arguments: const <String, Object?>{},
      );

      expect(failure, isNull);
    });

    test('rejects focus_window unknown keys', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'focus_window',
        arguments: const <String, Object?>{'unexpected': true},
      );

      expect(failure, isNotNull);
      expect(failure!.ok, isFalse);
      expect(failure.error!.code, CoreErrorCode.invalidCommand);
    });

    test('rejects scroll invalid direction enum', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'scroll',
        arguments: const <String, Object?>{'direction': 'sideways'},
      );

      expect(failure, isNotNull);
      expect(failure!.error!.message, contains('direction'));
      expect(failure.error!.message, contains('one of'));
    });

    test('accepts scroll valid direction enum', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'scroll',
        arguments: const <String, Object?>{'direction': 'down'},
      );

      expect(failure, isNull);
    });

    test('rejects get_screenshots invalid mode enum', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'get_screenshots',
        arguments: const <String, Object?>{'mode': 'invalid_mode'},
      );

      expect(failure, isNotNull);
      expect(failure!.error!.message, contains('mode'));
    });

    test('accepts get_screenshots valid mode and permissionPolicy', () {
      final failure = validationFailureForInteractionCatalogCommand(
        commandName: 'get_screenshots',
        arguments: const <String, Object?>{
          'mode': 'flutter_layer',
          'permissionPolicy': 'auto_request_once',
        },
      );

      expect(failure, isNull);
    });
  });

  group('CommandCatalog.buildCommand integration', () {
    final catalog = CommandCatalog.instance;

    test('fmt_tap_widget alias rejects missing ref', () {
      expect(
        () => catalog.buildCommand('fmt_tap_widget', <String, Object?>{}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fill_form rejects missing fields via shared schema', () {
      expect(
        () => catalog.buildCommand('fill_form', <String, Object?>{}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fmt_fill_form alias rejects missing fields', () {
      expect(
        () => catalog.buildCommand('fmt_fill_form', <String, Object?>{}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fmt_handle_dialog alias rejects missing action', () {
      expect(
        () => catalog.buildCommand('fmt_handle_dialog', <String, Object?>{}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fmt_navigate alias rejects missing action', () {
      expect(
        () => catalog.buildCommand('fmt_navigate', <String, Object?>{
          'route': '/settings',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('get_recent_logs rejects unknown keys via shared schema', () {
      expect(
        () => catalog.buildCommand('get_recent_logs', {'unexpected': true}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('evaluate_dart_expression rejects missing expression', () {
      expect(
        () => catalog.buildCommand('evaluate_dart_expression', {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fmt_evaluate_dart_expression alias rejects missing expression', () {
      expect(
        () => catalog.buildCommand('fmt_evaluate_dart_expression', {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('hot_reload_and_capture rejects unknown keys', () {
      expect(
        () => catalog.buildCommand('hot_reload_and_capture', {
          'unexpected': true,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('hot_reload_flutter rejects unknown keys via shared schema', () {
      expect(
        () => catalog.buildCommand('hot_reload_flutter', {'unexpected': true}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fmt_hot_reload_flutter alias rejects unknown keys', () {
      expect(
        () => catalog.buildCommand('fmt_hot_reload_flutter', {
          'unexpected': true,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('hot_restart_flutter rejects unknown keys via shared schema', () {
      expect(
        () => catalog.buildCommand('hot_restart_flutter', {'unexpected': true}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('inspect_widget_at_point rejects missing x and y', () {
      expect(
        () => catalog.buildCommand('inspect_widget_at_point', {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fmt_inspect_widget_at_point alias rejects missing x and y', () {
      expect(
        () => catalog.buildCommand('fmt_inspect_widget_at_point', {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('inspect_widget_at_point accepts origin coordinates', () {
      final command = catalog.buildCommand('inspect_widget_at_point', {
        'x': 0,
        'y': 0,
      });
      expect(command, isA<InspectWidgetAtPointCommand>());
      final inspect = command as InspectWidgetAtPointCommand;
      expect(inspect.x, 0);
      expect(inspect.y, 0);
    });

    test('get_view_details catalog schema matches shared core schema', () {
      expect(
        catalog.specFor('get_view_details')!.inputSchema,
        getViewDetailsInputSchema(),
      );
    });

    test(
      'inspect_widget_at_point catalog schema matches shared core schema',
      () {
        expect(
          catalog.specFor('inspect_widget_at_point')!.inputSchema,
          inspectWidgetAtPointInputSchema(),
        );
      },
    );

    test('get_app_errors catalog schema matches shared core schema', () {
      expect(
        catalog.specFor('get_app_errors')!.inputSchema,
        getAppErrorsInputSchema(),
      );
    });

    test('focus_window catalog schema matches shared core schema', () {
      expect(
        catalog.specFor('focus_window')!.inputSchema,
        focusWindowInputSchema(),
      );
    });

    test('get_view_details rejects unknown keys via shared schema', () {
      expect(
        () => catalog.buildCommand('get_view_details', {'unexpected': true}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('get_app_errors rejects unknown keys via shared schema', () {
      expect(
        () => catalog.buildCommand('get_app_errors', {'unexpected': true}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('focus_window rejects unknown keys via shared schema', () {
      expect(
        () => catalog.buildCommand('focus_window', {'unexpected': true}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('scroll rejects invalid direction via shared schema', () {
      expect(
        () => catalog.buildCommand('scroll', {'direction': 'sideways'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('connect catalog mode omits enum (Tier C docs only)', () {
      final props =
          catalog.specFor('connect')!.inputSchema['properties']!
              as Map<String, Object?>;
      final modeSchema = props['mode']! as Map<String, Object?>;
      expect(modeSchema.containsKey('enum'), isFalse);
      expect(modeSchema['description'], contains('auto'));
    });
  });
}
