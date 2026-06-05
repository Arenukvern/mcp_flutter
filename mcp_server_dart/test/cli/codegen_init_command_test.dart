// mcp_server_dart/test/cli/codegen_init_command_test.dart
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/cli/codegen_init_command.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/codegen_snippets.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('codegen_init_');
    File('${tmp.path}/pubspec.yaml').writeAsStringSync('''
name: my_flutter_app
environment:
  sdk: ">=3.11.0"
dependencies:
  flutter:
    sdk: flutter
''');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('runCodegenInit', () {
    test('--print-snippet emits to stdout without writing files', () async {
      final exitCode = await runCodegenInit(
        projectRoot: tmp.path,
        printSnippetOnly: true,
        runPubAdd: false,
      );
      expect(exitCode, 0);
      // No new files in the project root other than pubspec.yaml.
      expect(File('${tmp.path}/lib/main.dart').existsSync(), isFalse);
    });

    test('snippet imports the published mcp_toolkit package', () {
      // Regression guard: the package is published on pub.dev as `mcp_toolkit`.
      // `flutter_mcp_toolkit` does not exist there, so importing it in the
      // emitted boilerplate would break `flutter pub get` / compilation.
      expect(
        CodegenSnippets.flutterMainInit,
        contains("import 'package:mcp_toolkit/mcp_toolkit.dart';"),
      );
      expect(
        CodegenSnippets.flutterMainInit,
        isNot(contains('package:flutter_mcp_toolkit/')),
      );
    });

    test('refuses to run if pubspec.yaml is missing', () async {
      final emptyDir = Directory.systemTemp.createTempSync(
        'codegen_init_empty_',
      );
      try {
        final exitCode = await runCodegenInit(
          projectRoot: emptyDir.path,
          printSnippetOnly: true,
          runPubAdd: false,
        );
        expect(exitCode, isNot(0));
      } finally {
        emptyDir.deleteSync(recursive: true);
      }
    });
  });
}
