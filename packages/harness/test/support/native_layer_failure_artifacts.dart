import 'dart:io';

import 'native_capture_session_cleanup.dart';
import 'native_layer_evidence.dart';
import 'native_layer_oka_diagnostics.dart';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

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
  }
  await writeJsonArtifact(artifactDir, '${platform}_failure_bundle.json', payload);
}
