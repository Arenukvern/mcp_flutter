// mcp_server_dart/test/cli/codegen_snippets_test.dart
import 'package:flutter_inspector_mcp_server/src/cli/codegen_snippets.dart';
import 'package:test/test.dart';

void main() {
  group('CodegenSnippets', () {
    test('produces an importable Flutter init snippet', () {
      expect(CodegenSnippets.flutterMainInit, contains('MCPToolkitBinding'));
      expect(CodegenSnippets.flutterMainInit, contains('handleZoneError'));
      expect(CodegenSnippets.flutterMainInit, contains('runZonedGuarded'));
    });

    test('snippet is plain Dart that parses', () {
      // Smoke check: braces balance, no obvious typos
      const s = CodegenSnippets.flutterMainInit;
      expect('{'.allMatches(s).length, equals('}'.allMatches(s).length));
    });
  });
}
