import 'dart:convert';
import 'dart:io';

import 'package:flutter_inspector_mcp_server/src/shared_core/services/core_image_file_saver.dart';
import 'package:test/test.dart';

void main() {
  test('saveImageToFile writes under deterministic base directory', () async {
    final tempDir = Directory.systemTemp.createTempSync(
      'core_image_file_saver_test_',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final saver = CoreImageFileSaver(
      logger: (final level, final message, {final logger = 'test'}) {},
      baseDirectory: tempDir.path,
    );
    final bytes = base64Encode(List<int>.filled(8, 1));

    final fileUrl = await saver.saveImageToFile(bytes);

    expect(fileUrl, startsWith('file://'));
    final filePath = Uri.parse(fileUrl).toFilePath();
    expect(
      filePath,
      contains('${tempDir.path}/${CoreImageFileSaver.temporalFolderName}/'),
    );
    expect(File(filePath).existsSync(), isTrue);
  });
}
