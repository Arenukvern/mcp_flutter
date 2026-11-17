import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/visual_capture_target_platform.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/diagnostics/doctor_runner.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/command_executor.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/core_types.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/connection_context.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    testOnlyVisualCaptureTargetPlatformProbe = null;
  });

  test(
    'doctor run survives throwing visual capture platform probe',
    () async {
      testOnlyVisualCaptureTargetPlatformProbe =
          ({
            required CoreRuntimeConfiguration configuration,
            required ConnectionContext connectionContext,
            required Duration probeTimeout,
          }) async {
            throw StateError('paused native app');
          };

      final context = ConnectionContext(
        defaultHost: '127.0.0.1',
        defaultPort: 8181,
        logger: _noopLogger,
        discoverPorts: () async => <int>[],
        initialStickyEndpointUri: 'ws://127.0.0.1:8181/abc/ws',
      );

      final runner = DoctorRunner(
        connectionContext: context,
        executor: DefaultCoreCommandExecutor(
          connectionContext: context,
          portScanner: CorePortScanner(logger: _noopLogger),
          imageFileSaver: CoreImageFileSaver(logger: _noopLogger),
          configuration: const CoreRuntimeConfiguration(
            vmHost: '127.0.0.1',
            vmPort: 8181,
            resourcesSupported: true,
            imagesSupported: true,
            dumpsSupported: false,
            dynamicRegistrySupported: false,
            saveImagesToFiles: false,
          ),
        ),
        stateFilePath: '${Directory.systemTemp.path}/fmtk_doctor_test_state.json',
        dynamicRegistrySupported: false,
        logger: _noopLogger,
      );

      final result = await runner.run(
        target: 'ws://127.0.0.1:8181/abc/ws',
        timeout: const Duration(milliseconds: 200),
      );

      final checks = (result['checks'] as List).cast<Map<String, Object?>>();
      final platformWarn = checks.firstWhere(
        (c) => c['id'] == 'visual_capture_target_platform',
        orElse: () => throw StateError('missing visual_capture_target_platform check'),
      );
      expect(platformWarn['status'], 'warn');
      expect('${platformWarn['diagnostic']}', contains('StateError'));
    },
  );
}

void _noopLogger(
  LoggingLevel level,
  String message, {
  String logger = 'test',
}) {}