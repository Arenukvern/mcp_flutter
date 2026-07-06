import 'dart:io';

import 'package:intentcall_platform/intentcall_platform.dart';

import 'intentcall_delegate.dart';

/// Runs `flutter-mcp-toolkit codegen sync` by delegating to [intentcall_cli].
Future<int> runCodegenSync({
  required final String platform,
  required final String projectRoot,
  final bool checkOnly = false,
}) async {
  final platforms = platform
      .split(',')
      .map((final value) => value.trim().toLowerCase())
      .where((final value) => value.isNotEmpty)
      .toList();
  if (platforms.isEmpty) {
    stderr.writeln('Missing --platform (e.g. web,android,ios)');
    return 64;
  }

  final unknown = platforms.toSet().difference(kPlatformSyncTargets);
  if (unknown.isNotEmpty) {
    stderr.writeln(
      'Unsupported platform(s): ${unknown.join(', ')}. '
      'Supported: ${kPlatformSyncTargets.join(', ')}',
    );
    return 64;
  }

  try {
    return delegatePlatformSync(
      projectRoot: projectRoot,
      platforms: platforms,
      checkOnly: checkOnly,
    );
  } on Object catch (error) {
    stderr.writeln('codegen sync failed: $error');
    return 1;
  }
}
