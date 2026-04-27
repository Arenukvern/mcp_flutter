import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  final catalog = CommandCatalog.instance;

  group('PressKeyCommand', () {
    test('round-trips key + modifiers', () {
      final cmd = catalog.buildCommand('press_key', {
        'key': 'Tab',
        'shift': true,
        'ctrl': true,
      }) as PressKeyCommand;
      expect(cmd.key, 'Tab');
      expect(cmd.shift, isTrue);
      expect(cmd.ctrl, isTrue);
      expect(cmd.alt, isFalse);
      expect(cmd.meta, isFalse);
    });
  });

  group('HandleDialogCommand', () {
    test('default action is dismiss', () {
      final cmd = catalog.buildCommand('handle_dialog', {})
          as HandleDialogCommand;
      expect(cmd.action, 'dismiss');
    });
  });

  group('NavigateCommand', () {
    test('round-trips action + route + arguments', () {
      final cmd = catalog.buildCommand('navigate', {
        'action': 'push',
        'route': '/profile',
        'arguments': {'userId': 42},
      }) as NavigateCommand;
      expect(cmd.action, 'push');
      expect(cmd.route, '/profile');
      expect(cmd.arguments?['userId'], 42);
    });

    test('arguments null when omitted', () {
      final cmd = catalog.buildCommand('navigate', {
        'action': 'pop',
      }) as NavigateCommand;
      expect(cmd.arguments, isNull);
    });
  });
}
