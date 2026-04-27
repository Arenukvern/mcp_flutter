import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  group('MCPToolkitBinding navigator key registration', () {
    test('navigatorKey defaults to null', () {
      final binding = MCPToolkitBinding.instance;
      expect(binding.navigatorKey, isNull);
    });

    test('setNavigatorKey stores the key for later retrieval', () {
      final binding = MCPToolkitBinding.instance;
      final key = GlobalKey<NavigatorState>();
      try {
        binding.setNavigatorKey(key);
        expect(binding.navigatorKey, same(key));
      } finally {
        binding.setNavigatorKey(null);
      }
      expect(binding.navigatorKey, isNull);
    });
  });
}
