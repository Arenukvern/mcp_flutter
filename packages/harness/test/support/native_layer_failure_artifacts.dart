import 'dart:convert';
import 'dart:io';

import 'package:oka_android/oka_android.dart';

import 'native_capture_session_cleanup.dart';
import 'native_layer_evidence.dart';
import 'native_layer_oka_diagnostics.dart';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

const _attachHandshakeFailureFile = 'attach-handshake-failure.json';

/// SDK-authored attach failure diagnostic under `.flutter_mcp/` (a92e+).
Map<String, Object?>? readAttachHandshakeFailureArtifact(String projectDir) {
  final file = File('$projectDir/.flutter_mcp/$_attachHandshakeFailureFile');
  if (!file.existsSync()) return null;
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
    return {'parseError': 'not_a_map', 'path': file.path};
  } on Object catch (e) {
    return {'parseError': e.toString(), 'path': file.path};
  }
}

/// Persist launch/cleanup evidence when native capture aborts (no silent waits).
Future<void> persistNativeCaptureFailureBundle({
  required Directory artifactDir,
  required String platform,
  required NativeCaptureRunOutcome outcome,
  required LogTap combinedLogTap,
  String? projectDir,
}) async {
  final payload = <String, Object?>{
    'platform': platform,
    'outcome': outcome.toJson(),
    'combinedLogTail': combinedLogTap.tail(250),
    'combinedLogLineCount': combinedLogTap.lines.length,
  };
  if (platform == 'android' && projectDir != null) {
    payload['okaArtifactTree'] =
        await snapshotOkaAndroidArtifactTree(projectDir);
    payload['okaDevPreflight'] = await okaAndroidDevPreflightReport(
      projectDir: projectDir,
      checkDevice: false,
    );
    final attachDiag = readAttachHandshakeFailureArtifact(projectDir);
    if (attachDiag != null) {
      payload['attachHandshakeFailure'] = attachDiag;
      await writeJsonArtifact(
        artifactDir,
        'android_attach_handshake_failure.json',
        attachDiag,
      );
    }
    final rawTeardown = readSessionTeardownFile(projectDir);
    if (rawTeardown != null) {
      payload['rawSessionTeardownFile'] = rawTeardown;
    }
  }
  await writeJsonArtifact(artifactDir, '${platform}_failure_bundle.json', payload);
}
