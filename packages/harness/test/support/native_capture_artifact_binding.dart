import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'native_layer_evidence.dart';

/// Cryptographic binding for capture PNG/JSON artifacts (provenance, not gate).
Future<Map<String, Object?>> digestArtifactFile(File file) async {
  if (!file.existsSync()) {
    return {
      'path': file.path,
      'present': false,
    };
  }
  final bytes = await file.readAsBytes();
  final digest = sha256.convert(bytes);
  return {
    'path': file.path,
    'present': true,
    'bytes': bytes.length,
    'sha256': digest.toString(),
    'md5': md5.convert(bytes).toString(),
  };
}

Future<void> writeNativeCaptureArtifactBindings({
  required Directory artifactDir,
  required String platform,
  required Uint8List beforePng,
  required Uint8List afterPng,
  Uint8List? cliPng,
}) async {
  final beforeFile = File('${artifactDir.path}/${platform}_before_increment.png');
  final afterFile = File('${artifactDir.path}/${platform}_after_increment.png');
  final cliFile = cliPng == null
      ? null
      : File('${artifactDir.path}/${platform}_cli_compressed.png');
  final bindings = <String, Object?>{
    'platform': platform,
    'boundAt': DateTime.now().toUtc().toIso8601String(),
    'beforeIncrementPng': await digestArtifactFile(beforeFile),
    'afterIncrementPng': await digestArtifactFile(afterFile),
    if (cliFile != null)
      'cliCompressedPng': await digestArtifactFile(cliFile),
    'inMemoryBeforeBytes': beforePng.length,
    'inMemoryAfterBytes': afterPng.length,
    if (cliPng != null) 'inMemoryCliBytes': cliPng.length,
    'note':
        'sha256/md5 of on-disk artifacts after writePng; compare across CI runs for determinism.',
  };
  await writeJsonArtifact(
    artifactDir,
    '${platform}_capture_artifact_bindings.json',
    bindings,
  );
}
