import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  final catalog = CommandCatalog.instance;

  group('PressKeyCommand', () {
    test('round-trips key + modifiers', () {
      final cmd =
          catalog.buildCommand('press_key', {
                'key': 'Tab',
                'shift': true,
                'ctrl': true,
              })
              as PressKeyCommand;
      expect(cmd.key, 'Tab');
      expect(cmd.shift, isTrue);
      expect(cmd.ctrl, isTrue);
      expect(cmd.alt, isFalse);
      expect(cmd.meta, isFalse);
    });
  });

  group('HandleDialogCommand', () {
    test('requires action at catalog boundary', () {
      expect(
        () => catalog.buildCommand('handle_dialog', {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('round-trips explicit dismiss action', () {
      final cmd =
          catalog.buildCommand('handle_dialog', {'action': 'dismiss'})
              as HandleDialogCommand;
      expect(cmd.action, 'dismiss');
    });
  });

  group('NavigateCommand', () {
    test('round-trips action + route + arguments', () {
      final cmd =
          catalog.buildCommand('navigate', {
                'action': 'push',
                'route': '/profile',
                'arguments': {'userId': 42},
              })
              as NavigateCommand;
      expect(cmd.action, 'push');
      expect(cmd.route, '/profile');
      expect(cmd.arguments?['userId'], 42);
    });

    test('arguments null when omitted', () {
      final cmd =
          catalog.buildCommand('navigate', {'action': 'pop'})
              as NavigateCommand;
      expect(cmd.arguments, isNull);
    });
  });
}
