// mcp_server_dart/lib/src/cli/codegen_init_command.dart
import 'dart:io';
import 'codegen_snippets.dart';

Future<int> runCodegenInit({
  required final String projectRoot,
  required final bool printSnippetOnly,
  required final bool runPubAdd,
}) async {
  final pubspec = File('$projectRoot/pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln(
      'No pubspec.yaml at $projectRoot. Run from a Flutter project root.',
    );
    return 66;
  }
  if (runPubAdd) {
    final result = await Process.start(
      'flutter',
      ['pub', 'add', 'flutter_mcp_toolkit'],
      workingDirectory: projectRoot,
      mode: ProcessStartMode.inheritStdio,
    );
    final exit = await result.exitCode;
    if (exit != 0) {
      stderr.writeln('flutter pub add failed (exit $exit)');
      return exit;
    }
  }
  // For v3.0.0: emit snippet to stdout only. AST-edit of main.dart is a follow-up.
  stdout.writeln(
    '=== flutter-mcp-toolkit: paste this into your lib/main.dart ===',
  );
  stdout.writeln(CodegenSnippets.flutterMainInit);
  stdout.writeln('=== end ===');
  return 0;
}
