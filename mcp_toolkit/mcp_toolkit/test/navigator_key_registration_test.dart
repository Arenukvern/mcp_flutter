import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  group('MCPToolkitBinding navigator key registration', () {
    test('navigatorKey defaults to null', () {
      final binding = MCPToolkitBinding.instance;
      expect(binding.navigatorKey, isNull);
    });

    test('navigatorKey setter stores the key for later retrieval', () {
      final binding = MCPToolkitBinding.instance;
      final key = GlobalKey<NavigatorState>();
      try {
        binding.navigatorKey = key;
        expect(binding.navigatorKey, same(key));
      } finally {
        binding.navigatorKey = null;
      }
      expect(binding.navigatorKey, isNull);
    });
  });
}
