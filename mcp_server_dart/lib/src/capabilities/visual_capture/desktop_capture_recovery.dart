// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/desktop_window_screenshot.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_cdp_client.dart';

/// Result of a desktop capture attempt, optionally after one recovery cycle.
final class DesktopCaptureRecoveryResult {
  const DesktopCaptureRecoveryResult({
    this.capture,
    this.retried = false,
    this.errorMessage,
    this.errorDetails = const <String, Object?>{},
    this.failure,
  });

  final DesktopWindowScreenshotCapture? capture;
  final bool retried;
  final String? errorMessage;
  final Map<String, Object?> errorDetails;
  final Object? failure;

  Map<String, Object?> recoveryMetadata() => <String, Object?>{
    if (retried) 'desktopCaptureRetried': true,
    if (retried) 'desktopCaptureRecovery': 'focus_and_capture',
  };
}

/// Resolves `auto` to [ScreenshotMode.desktopWindow] when platform views need
/// host pixels and the macOS host can capture.
ScreenshotMode resolveEffectiveScreenshotMode({
  required final ScreenshotMode requested,
  required final PlatformViewHints hints,
  required final bool hostDesktopCaptureViable,
}) {
  if (requested == ScreenshotMode.auto &&
      hints.platformViewsDetected &&
      hostDesktopCaptureViable) {
    return ScreenshotMode.desktopWindow;
  }
  return requested;
}

/// Whether a second focus+capture cycle may help after the first failure.
bool shouldAttemptDesktopRecovery({
  required final PlatformViewHints hints,
  required final bool explicitDesktopMode,
}) => hints.platformViewsDetected || explicitDesktopMode;

/// Matches retryable host capture failures (window focus, permissions, SCK).
bool isRetryableDesktopCaptureFailure({
  final Object? error,
  final String? message,
  final Map<String, Object?> details = const <String, Object?>{},
}) {
  final text = '${message ?? error ?? ''} $details'.toLowerCase();
  if (text.contains('desktop window') ||
      text.contains('desktop_window') ||
      text.contains('screencapturekit') ||
      text.contains('window_not_found') ||
      text.contains('window') ||
      text.contains('permission') ||
      text.contains('offscreen') ||
      text.contains('hidden') ||
      text.contains('unavailable')) {
    return true;
  }
  if (error is DesktopWindowCaptureException) {
    return true;
  }
  if (error is WebCdpCaptureException) {
    return isRetryableWebCdpFailure(error);
  }
  return false;
}

/// Runs host desktop capture with at most one extra focus+capture recovery cycle.
///
/// [DesktopWindowScreenshotService.capture] already focuses once; recovery adds
/// a second focus+capture only when the first attempt fails.
Future<DesktopCaptureRecoveryResult> captureDesktopWithRecovery({
  required final DesktopWindowScreenshotService service,
  required final String projectDir,
  required final String device,
  required final bool compress,
  required final int? targetPid,
  required final String? cacheDir,
  required final PlatformViewHints hints,
  required final bool explicitDesktopMode,
}) async {
  final first = await _attemptCapture(
    service: service,
    projectDir: projectDir,
    device: device,
    compress: compress,
    targetPid: targetPid,
    cacheDir: cacheDir,
  );
  if (first.capture != null) {
    return first;
  }

  if (!shouldAttemptDesktopRecovery(
        hints: hints,
        explicitDesktopMode: explicitDesktopMode,
      ) ||
      !isRetryableDesktopCaptureFailure(
        error: first.failure,
        message: first.errorMessage,
        details: first.errorDetails,
      )) {
    return first;
  }

  await service.focus(device: device, targetPid: targetPid, cacheDir: cacheDir);
  final second = await _attemptCapture(
    service: service,
    projectDir: projectDir,
    device: device,
    compress: compress,
    targetPid: targetPid,
    cacheDir: cacheDir,
  );
  return DesktopCaptureRecoveryResult(
    capture: second.capture,
    retried: true,
    errorMessage: second.errorMessage,
    errorDetails: second.errorDetails,
    failure: second.failure,
  );
}

Future<DesktopCaptureRecoveryResult> _attemptCapture({
  required final DesktopWindowScreenshotService service,
  required final String projectDir,
  required final String device,
  required final bool compress,
  required final int? targetPid,
  required final String? cacheDir,
}) async {
  try {
    final capture = await service.capture(
      projectDir: projectDir,
      device: device,
      compress: compress,
      targetPid: targetPid,
      cacheDir: cacheDir,
    );
    if (capture != null) {
      return DesktopCaptureRecoveryResult(capture: capture);
    }
    return const DesktopCaptureRecoveryResult(
      errorMessage:
          'Desktop window screenshot mode is unavailable for the current '
          'target or app window.',
    );
  } on DesktopWindowCaptureException catch (e) {
    return DesktopCaptureRecoveryResult(
      errorMessage: 'Desktop window screenshot failed: $e',
      errorDetails: e.details,
      failure: e,
    );
  } on WebCdpCaptureException catch (e) {
    return DesktopCaptureRecoveryResult(
      errorMessage: e.message,
      errorDetails: <String, Object?>{'code': e.code, ...e.details},
      failure: e,
    );
  } on Object catch (e) {
    return DesktopCaptureRecoveryResult(
      errorMessage: 'Desktop window screenshot failed: $e',
      failure: e,
    );
  }
}
