import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('preconnectForExecution', () {
    late Directory tempDir;
    late String statePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_mcp_preconnect_');
      statePath = '${tempDir.path}/state.json';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'implicit stale active session attach failure falls back to auto policy',
      () async {
        final store = StateStore(path: statePath);
        await store.write(
          const PersistedState(
            activeSessionId: 'stale-session',
          ),
        );

        final context = ConnectionContext(
          defaultHost: 'localhost',
          defaultPort: 8181,
          logger: _noopLogger,
          discoverPorts: () async => <int>[8181, 8182],
        );

        final manager = SessionManager(
          connectionContext: context,
          stateStore: store,
        );
        await manager.load();

        final executor = _buildExecutor(
          context: context,
          sessionManager: manager,
        );

        final preconnect = await preconnectForExecution(
          command: const GetVmCommand(),
          executor: executor,
          sessionManager: manager,
        );
        expect(preconnect, isNull);

        final result = await executor.execute(const GetVmCommand());
        expect(result.ok, isFalse);
        expect(
          result.error?.code,
          equals(CoreErrorCode.connectionSelectionRequired),
        );
      },
    );

    test('explicit requested session attach failures stay strict', () async {
      final store = StateStore(path: statePath);
      final context = ConnectionContext(
        defaultHost: 'localhost',
        defaultPort: 8181,
        logger: _noopLogger,
        discoverPorts: () async => <int>[8181, 8182],
      );

      final manager = SessionManager(
        connectionContext: context,
        stateStore: store,
      );
      await manager.load();

      final executor = _buildExecutor(
        context: context,
        sessionManager: manager,
      );

      final preconnect = await preconnectForExecution(
        command: const SessionExecCommand(
          sessionId: 'missing-session',
          command: GetVmCommand(),
        ),
        executor: executor,
        sessionManager: manager,
      );
      expect(preconnect, isNotNull);
      expect(preconnect!.error?.code, equals(CoreErrorCode.sessionNotFound));
    });

    test(
      'explicit connection override runs before command execution',
      () async {
        final context = ConnectionContext(
          defaultHost: 'localhost',
          defaultPort: 8181,
          logger: _noopLogger,
          discoverPorts: () async => <int>[8181],
        );

        final executor = _buildExecutor(context: context, sessionManager: null);

        final preconnect = await preconnectForExecution(
          command: const StatusCommand(),
          executor: executor,
          sessionManager: null,
          explicitConnectionOverride: const ConnectCommand(
            targetId: 'ws://localhost:9999/ws',
          ),
        );
        expect(preconnect, isNotNull);
        expect(preconnect!.error?.code, equals(CoreErrorCode.connectFailed));
        expect(
          (preconnect.error!.details! as Map<String, Object?>)['reason'],
          equals('target_not_found'),
        );
      },
    );
  });
}

DefaultCoreCommandExecutor _buildExecutor({
  required final ConnectionContext context,
  required final SessionManager? sessionManager,
}) => DefaultCoreCommandExecutor(
    connectionContext: context,
    portScanner: const CorePortScanner(logger: _noopLogger),
    imageFileSaver: const CoreImageFileSaver(logger: _noopLogger),
    configuration: const CoreRuntimeConfiguration(
      vmHost: 'localhost',
      vmPort: 8181,
      resourcesSupported: true,
      imagesSupported: true,
      dumpsSupported: false,
      dynamicRegistrySupported: false,
      saveImagesToFiles: false,
    ),
    sessionManager: sessionManager,
  );

void _noopLogger(
  final LoggingLevel level,
  final String message, {
  final String logger = 'test',
}) {}
