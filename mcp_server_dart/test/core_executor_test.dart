import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/desktop_window_screenshot.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultCoreCommandExecutor', () {
    late DefaultCoreCommandExecutor executor;

    setUp(() {
      void logger(
        final LoggingLevel level,
        final String message, {
        final String logger = 'test',
      }) {}

      final context = ConnectionContext(
        defaultHost: 'localhost',
        defaultPort: 8181,
        logger: logger,
        discoverPorts: () async => <int>[8181],
      );

      executor = DefaultCoreCommandExecutor(
        connectionContext: context,
        portScanner: CorePortScanner(logger: logger),
        imageFileSaver: CoreImageFileSaver(logger: logger),
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: false,
          saveImagesToFiles: false,
        ),
      );
    });

    test('status command returns normalized data', () async {
      final result = await executor.execute(const StatusCommand());

      expect(result.ok, isTrue);
      final data = result.data! as Map<String, Object?>;
      expect(data['connected'], isFalse);
      expect(result.meta.containsKey('durationMs'), isTrue);
      expect(result.meta['schemaVersion'], equals('core-envelope/v1'));
      expect(result.meta['command'], equals('status'));
      expect(result.meta['timestamp'], isA<String>());
    });

    test('desktop window screenshot mode succeeds without VM bridge', () async {
      void logger(
        final LoggingLevel level,
        final String message, {
        final String logger = 'test',
      }) {}

      final localExecutor = DefaultCoreCommandExecutor(
        connectionContext: ConnectionContext(
          defaultHost: 'localhost',
          defaultPort: 8181,
          logger: logger,
          discoverPorts: () async => <int>[8181],
        ),
        portScanner: CorePortScanner(logger: logger),
        imageFileSaver: CoreImageFileSaver(logger: logger),
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: false,
          saveImagesToFiles: false,
          flutterProjectDir: '/tmp/sample_app',
          flutterDevice: 'macos',
        ),
        desktopWindowScreenshotService:
            const _FakeDesktopWindowScreenshotService(
              result: DesktopWindowScreenshotCapture(
                images: <String>['AQID'],
                captureMode: 'desktop_window',
                metadata: <String, Object?>{'appName': 'sample_app'},
              ),
            ),
      );

      final result = await localExecutor.execute(
        const GetScreenshotsCommand(mode: ScreenshotMode.desktopWindow),
      );

      expect(result.ok, isTrue);
      final data = result.data! as Map<String, Object?>;
      expect(data['captureMode'], equals('desktop_window'));
      expect(data['appName'], equals('sample_app'));
      expect(data['images'], equals(const <String>['AQID']));
    });

    test(
      'desktop window screenshot forwards vm pid into capture service',
      () async {
        void logger(
          final LoggingLevel level,
          final String message, {
          final String logger = 'test',
        }) {}

        final context = ConnectionContext(
          defaultHost: 'localhost',
          defaultPort: 8181,
          logger: logger,
          discoverPorts: () async => <int>[8181],
        );
        context.debugConnectedVmPidOverride = 90001;
        addTearDown(() => context.debugConnectedVmPidOverride = null);

        int? capturedPid;
        final localExecutor = DefaultCoreCommandExecutor(
          connectionContext: context,
          portScanner: CorePortScanner(logger: logger),
          imageFileSaver: CoreImageFileSaver(logger: logger),
          configuration: const CoreRuntimeConfiguration(
            vmHost: 'localhost',
            vmPort: 8181,
            resourcesSupported: true,
            imagesSupported: true,
            dumpsSupported: false,
            dynamicRegistrySupported: false,
            saveImagesToFiles: false,
            flutterProjectDir: '/tmp/sample_app',
            flutterDevice: 'macos',
          ),
          desktopWindowScreenshotService: _FakeDesktopWindowScreenshotService(
            result: const DesktopWindowScreenshotCapture(
              images: <String>['AQID'],
              captureMode: 'desktop_window',
              metadata: <String, Object?>{'appName': 'sample_app'},
            ),
            onCapture: (final pid) => capturedPid = pid,
          ),
        );

        final result = await localExecutor.execute(
          const GetScreenshotsCommand(mode: ScreenshotMode.desktopWindow),
        );

        expect(result.ok, isTrue);
        expect(capturedPid, equals(90001));
      },
    );

    test('desktop window screenshot mode surfaces capture failures', () async {
      void logger(
        final LoggingLevel level,
        final String message, {
        final String logger = 'test',
      }) {}

      final localExecutor = DefaultCoreCommandExecutor(
        connectionContext: ConnectionContext(
          defaultHost: 'localhost',
          defaultPort: 8181,
          logger: logger,
          discoverPorts: () async => <int>[8181],
        ),
        portScanner: CorePortScanner(logger: logger),
        imageFileSaver: CoreImageFileSaver(logger: logger),
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: false,
          saveImagesToFiles: false,
          flutterProjectDir: '/tmp/sample_app',
          flutterDevice: 'macos',
        ),
        desktopWindowScreenshotService: _FakeDesktopWindowScreenshotService(
          error: StateError('screen permission missing'),
        ),
      );

      final result = await localExecutor.execute(
        const GetScreenshotsCommand(mode: ScreenshotMode.desktopWindow),
      );

      expect(result.ok, isFalse);
      expect(result.error?.code, equals(CoreErrorCode.getScreenshotsFailed));
      expect(result.error?.message, contains('screen permission missing'));
    });

    test(
      'desktop window screenshot mode preserves structured capture diagnostics',
      () async {
        void logger(
          final LoggingLevel level,
          final String message, {
          final String logger = 'test',
        }) {}

        final localExecutor = DefaultCoreCommandExecutor(
          connectionContext: ConnectionContext(
            defaultHost: 'localhost',
            defaultPort: 8181,
            logger: logger,
            discoverPorts: () async => <int>[8181],
          ),
          portScanner: CorePortScanner(logger: logger),
          imageFileSaver: CoreImageFileSaver(logger: logger),
          configuration: const CoreRuntimeConfiguration(
            vmHost: 'localhost',
            vmPort: 8181,
            resourcesSupported: true,
            imagesSupported: true,
            dumpsSupported: false,
            dynamicRegistrySupported: false,
            saveImagesToFiles: false,
            flutterProjectDir: '/tmp/sample_app',
            flutterDevice: 'macos',
          ),
          desktopWindowScreenshotService:
              const _FakeDesktopWindowScreenshotService(
                error: DesktopWindowCaptureException(
                  message:
                      'macOS desktop window capture failed: window_not_found',
                  details: <String, Object?>{
                    'visibleOwners': <String>['Codex'],
                    'allOwners': <String>['Codex', 'sample_app'],
                  },
                ),
              ),
        );

        final result = await localExecutor.execute(
          const GetScreenshotsCommand(mode: ScreenshotMode.desktopWindow),
        );

        expect(result.ok, isFalse);
        expect(result.error?.code, equals(CoreErrorCode.getScreenshotsFailed));
        final details = result.error?.details as Map<String, Object?>?;
        expect(details?['desktopWindow'], isA<Map<String, Object?>>());
        final desktopWindow =
            details?['desktopWindow'] as Map<String, Object?>?;
        expect(desktopWindow?['desktopCaptureRetried'], isTrue);
        final firstAttempt =
            desktopWindow?['firstAttempt'] as Map<String, Object?>?;
        final firstAttemptDetails =
            firstAttempt?['details'] as Map<String, Object?>?;
        expect(
          firstAttemptDetails?['allOwners'],
          equals(const <String>['Codex', 'sample_app']),
        );
      },
    );

    test('auto-request surfaces actionable permission denial', () async {
      void logger(
        final LoggingLevel level,
        final String message, {
        final String logger = 'test',
      }) {}

      final localExecutor = DefaultCoreCommandExecutor(
        connectionContext: ConnectionContext(
          defaultHost: 'localhost',
          defaultPort: 8181,
          logger: logger,
          discoverPorts: () async => <int>[8181],
        ),
        portScanner: CorePortScanner(logger: logger),
        imageFileSaver: CoreImageFileSaver(logger: logger),
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: false,
          saveImagesToFiles: false,
          flutterProjectDir: '/tmp/sample_app',
          flutterDevice: 'macos',
        ),
        desktopWindowScreenshotService:
            const _FakeDesktopWindowScreenshotService(
              permissionStatus: PermissionStatus.denied,
            ),
      );

      final result = await localExecutor.execute(
        const GetScreenshotsCommand(
          permissionPolicy: PermissionPolicy.autoRequestOnce,
        ),
      );

      expect(result.ok, isFalse);
      expect(
        result.error?.code,
        equals(CoreErrorCode.visualCapturePermissionDenied),
      );
      final details = result.error?.details as Map<String, Object?>?;
      expect(details?['permission'], isA<Map<String, Object?>>());
    });

    test('dynamic commands are rejected when disabled', () async {
      final result = await executor.execute(
        const ListClientToolsAndResourcesCommand(),
      );

      expect(result.ok, isFalse);
      expect(result.error?.code, equals('dynamic_registry_disabled'));
    });

    test('auto ambiguity returns connection_selection_required', () async {
      void logger(
        final LoggingLevel level,
        final String message, {
        final String logger = 'test',
      }) {}

      final context = ConnectionContext(
        defaultHost: 'localhost',
        defaultPort: 8181,
        logger: logger,
        discoverPorts: () async => <int>[8181, 8182],
        probeFlutterTarget: (final endpoint, {required final timeout}) async =>
            true,
      );

      final localExecutor = DefaultCoreCommandExecutor(
        connectionContext: context,
        portScanner: CorePortScanner(logger: logger),
        imageFileSaver: CoreImageFileSaver(logger: logger),
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: false,
          saveImagesToFiles: false,
        ),
      );

      final result = await localExecutor.execute(const GetVmCommand());

      expect(result.ok, isFalse);
      expect(
        result.error?.code,
        equals(CoreErrorCode.connectionSelectionRequired),
      );

      final details = result.error?.details as Map<String, Object?>?;
      expect(details?['reason'], equals('multiple_targets'));
      expect(details?['availableTargets'], isA<List<Object?>>());
      expect(
        details?['suggestedAction'],
        equals('retry_with_connection_target'),
      );
      expect(details?['example'], isA<Map<String, Object?>>());
      final available = (details?['availableTargets'] as List<Object?>?) ?? [];
      final firstTarget = available.first! as Map<String, Object?>;
      expect(firstTarget['targetId'], startsWith('ws://'));
    });

    test('unknown targetId returns connect_failed target_not_found', () async {
      void logger(
        final LoggingLevel level,
        final String message, {
        final String logger = 'test',
      }) {}

      final context = ConnectionContext(
        defaultHost: 'localhost',
        defaultPort: 8181,
        logger: logger,
        discoverPorts: () async => <int>[8181, 8182],
      );

      final localExecutor = DefaultCoreCommandExecutor(
        connectionContext: context,
        portScanner: CorePortScanner(logger: logger),
        imageFileSaver: CoreImageFileSaver(logger: logger),
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: false,
          saveImagesToFiles: false,
        ),
      );

      final result = await localExecutor.execute(
        const ConnectCommand(targetId: 'ws://localhost:9999/ws'),
      );

      expect(result.ok, isFalse);
      expect(result.error?.code, equals(CoreErrorCode.connectFailed));
      final details = result.error?.details as Map<String, Object?>?;
      expect(details?['reason'], equals('target_not_found'));
      expect(details?['availableTargets'], isA<List<Object?>>());
    });

    test(
      'tokenized targetId bypasses discovery lookup and attempts direct connect',
      () async {
        void logger(
          final LoggingLevel level,
          final String message, {
          final String logger = 'test',
        }) {}

        final context = ConnectionContext(
          defaultHost: 'localhost',
          defaultPort: 8181,
          logger: logger,
          discoverPorts: () async => <int>[8181, 8182],
        );

        final localExecutor = DefaultCoreCommandExecutor(
          connectionContext: context,
          portScanner: CorePortScanner(logger: logger),
          imageFileSaver: CoreImageFileSaver(logger: logger),
          configuration: const CoreRuntimeConfiguration(
            vmHost: 'localhost',
            vmPort: 8181,
            resourcesSupported: true,
            imagesSupported: true,
            dumpsSupported: false,
            dynamicRegistrySupported: false,
            saveImagesToFiles: false,
          ),
        );

        final result = await localExecutor.execute(
          const ConnectCommand(targetId: 'ws://127.0.0.1:9999/token/ws'),
        );

        expect(result.ok, isFalse);
        expect(result.error?.code, equals(CoreErrorCode.connectFailed));

        final details = result.error?.details;
        if (details is Map<String, Object?>) {
          expect(details['reason'], isNot(equals('target_not_found')));
        }
      },
    );

    test('legacy host:port targetId returns migration error', () async {
      void logger(
        final LoggingLevel level,
        final String message, {
        final String logger = 'test',
      }) {}

      final context = ConnectionContext(
        defaultHost: 'localhost',
        defaultPort: 8181,
        logger: logger,
        discoverPorts: () async => <int>[8181],
      );

      final localExecutor = DefaultCoreCommandExecutor(
        connectionContext: context,
        portScanner: CorePortScanner(logger: logger),
        imageFileSaver: CoreImageFileSaver(logger: logger),
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: false,
          saveImagesToFiles: false,
        ),
      );

      final result = await localExecutor.execute(
        const ConnectCommand(targetId: 'localhost:8181'),
      );

      expect(result.ok, isFalse);
      expect(result.error?.code, equals(CoreErrorCode.connectFailed));
      final details = result.error?.details as Map<String, Object?>?;
      expect(details?['reason'], equals('invalid_target_id_legacy_host_port'));
      expect(details?['migrationHint'], isA<String>());
    });
  });
}

final class _FakeDesktopWindowScreenshotService
    implements DesktopWindowScreenshotService, VisualCapturePlatformAdapter {
  const _FakeDesktopWindowScreenshotService({
    this.result,
    this.error,
    this.permissionStatus = PermissionStatus.granted,
    this.onCapture,
  });

  final DesktopWindowScreenshotCapture? result;
  final Object? error;
  final PermissionStatus permissionStatus;
  final void Function(int? targetPid)? onCapture;

  @override
  String get backend => 'fake_macos';

  @override
  Set<CaptureCapability> get capabilities => const <CaptureCapability>{
    CaptureCapability.desktopWindow,
    CaptureCapability.flutterLayer,
  };

  @override
  PermissionOwner get owner => PermissionOwner.host;

  @override
  Set<String> get supportedModes => const <String>{
    screenshotModeDesktopWindow,
    screenshotModeFlutterLayer,
  };

  @override
  String get truthMode => screenshotModeDesktopWindow;

  @override
  bool supportsPlatform(final String effectivePlatform) =>
      effectivePlatform == 'macos';

  @override
  Future<Map<String, Object?>> focus({
    required final String device,
    final int? targetPid,
    final String? cacheDir,
  }) async => <String, Object?>{'ok': true};

  @override
  Future<DesktopWindowScreenshotCapture?> capture({
    required final String projectDir,
    required final String device,
    required final bool compress,
    final int? targetPid,
    final String? cacheDir,
  }) async {
    onCapture?.call(targetPid);
    if (error != null) {
      // ignore: only_throw_errors
      throw error!;
    }
    return result;
  }

  @override
  Future<PermissionBrokerResult> status({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) async => PermissionBrokerResult(
    kind: kind,
    status: permissionStatus,
    policy: policy,
    owner: owner,
    backend: backend,
    capabilities: capabilities,
    supportedModes: supportedModes,
    truthMode: truthMode,
    canRequest: true,
    canOpenSettings: true,
  );

  @override
  Future<PermissionBrokerResult> request({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) => status(kind: kind, policy: policy, configuration: configuration);

  @override
  Future<PermissionBrokerResult> openSettings({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) => status(kind: kind, policy: policy, configuration: configuration);
}
