import 'dart:io';

import 'package:oka_android/oka_android.dart';

import 'native_capture_session_cleanup.dart';
import 'native_layer_evidence.dart';
import 'native_layer_oka_diagnostics.dart';
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

/// SDK `.flutter_mcp/attach-handshake-failure.json` (pre-launch or attach abort).
const attachHandshakeFailureSourceName = 'attach-handshake-failure.json';

/// Raw copy of an SDK sidecar into [artifactDir] (no parse/re-encode).
Future<String?> copyFlutterMcpSidecarToArtifacts({
  required String projectDir,
  required Directory artifactDir,
  required String sourceFileName,
  required String artifactFileName,
}) async {
  final src = File('$projectDir/.flutter_mcp/$sourceFileName');
  if (!src.existsSync()) return null;
  await artifactDir.create(recursive: true);
  final dest = File('${artifactDir.path}/$artifactFileName');
  await src.copy(dest.path);
  return artifactFileName;
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
    final attachFile = await copyFlutterMcpSidecarToArtifacts(
      projectDir: projectDir,
      artifactDir: artifactDir,
      sourceFileName: attachHandshakeFailureSourceName,
      artifactFileName: 'android_attach_handshake_failure.json',
    );
    if (attachFile != null) {
      payload['attachHandshakeFailureArtifactFile'] = attachFile;
    }
    final teardownFile = await copyFlutterMcpSidecarToArtifacts(
      projectDir: projectDir,
      artifactDir: artifactDir,
      sourceFileName: sessionTeardownFileName,
      artifactFileName: 'android_session_teardown_raw.json',
    );
    if (teardownFile != null) {
      payload['rawSessionTeardownArtifactFile'] = teardownFile;
    }
  }
  await writeJsonArtifact(artifactDir, '${platform}_failure_bundle.json', payload);
}
