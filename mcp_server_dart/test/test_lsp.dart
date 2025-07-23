#!/usr/bin/env dart
// Test script for the Dart LSP client

import 'dart:io';

import 'package:flutter_inspector_mcp_server/src/services/dart_lsp_client.dart';
import 'package:logging/logging.dart';

Future<void> main() async {
  // Setup logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((final record) {
    print('${record.level.name}: ${record.message}');
  });

  final logger = Logger('LSPTest');
  final lspClient = DartLspClient(logger: logger);

  try {
    logger.info('Starting LSP client...');
    final started = await lspClient.start();

    if (!started) {
      logger.severe('Failed to start LSP client');
      exit(1);
    }

    logger.info('LSP client started successfully!');

    // Create a simple test file
    final testFile = File('test_hover.dart');
    await testFile.writeAsString('''
/// A simple test class
class TestClass {
  /// A test method
  void testMethod() {
    print('Hello, World!');
  }
}

void main() {
  final test = TestClass();
  test.testMethod();
}
''');

    try {
      logger.info('Testing hover on TestClass...');
      final hover = await lspClient.getHover(
        testFile.absolute.path,
        1, // Line with "class TestClass"
        6, // Character position
      );

      if (hover != null) {
        logger.info('Hover result:\n$hover');
      } else {
        logger.warning('No hover result');
      }

      logger.info('Testing symbol search...');
      final symbolDoc = await lspClient.findSymbolDocumentation(
        testFile.absolute.path,
        'TestClass',
      );

      if (symbolDoc != null) {
        logger.info('Symbol documentation:\n$symbolDoc');
      } else {
        logger.warning('No symbol documentation found');
      }
    } finally {
      // Clean up
      if (testFile.existsSync()) {
        await testFile.delete();
      }
    }

    logger.info('Test completed successfully!');
  } catch (e, stackTrace) {
    logger.severe('Error: $e', e, stackTrace);
    exit(1);
  } finally {
    await lspClient.shutdown();
  }
}
