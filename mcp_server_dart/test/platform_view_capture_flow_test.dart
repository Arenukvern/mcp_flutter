import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/desktop_window_screenshot.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/platform_view_hints.dart';
import 'package:test/test.dart';

Map<String, Object?> _uiKitViewDebugPayload() => <String, Object?>{
  'widgetTree': <String, Object?>{
    'widgetType': 'Scaffold',
    'children': <Object?>[
      <String, Object?>{
        'widgetType': 'UiKitView',
        'renderObjectType': 'RenderUiKitView',
        'children': const <Object?>[],
      },
    ],
  },
};

void main() {
  group('platform view capture flow', () {
    test(
      'desktop_window with recovery metadata when capture retried',
      () async {
        void logger(
          final LoggingLevel level,
          final String message, {
          final String logger = 'test',
        }) {}

        var captureAttempts = 0;
        final executor = DefaultCoreCommandExecutor(
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
          desktopWindowScreenshotService: _RetryOnceFakeAdapter(
            onCapture: () => captureAttempts++,
          ),
        );

        final result = await executor.execute(
          const GetScreenshotsCommand(mode: ScreenshotMode.desktopWindow),
        );

        expect(result.ok, isTrue);
        expect(captureAttempts, 2);
        final data = result.data! as Map<String, Object?>;
        expect(data['desktopCaptureRetried'], isTrue);
        expect(data['desktopCaptureRecovery'], 'focus_and_capture');
      },
    );

    test(
      'desktop failure returns error without flutter_layer images',
      () async {
        void logger(
          final LoggingLevel level,
          final String message, {
          final String logger = 'test',
        }) {}

        final executor = DefaultCoreCommandExecutor(
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
          desktopWindowScreenshotService: const _AlwaysFailFakeAdapter(),
        );

        final result = await executor.execute(
          const GetScreenshotsCommand(mode: ScreenshotMode.desktopWindow),
        );

        expect(result.ok, isFalse);
        expect(result.error?.code, CoreErrorCode.getScreenshotsFailed);
      },
    );

    test(
      'auto upgrades to desktop_window when UiKitView in debug payload',
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
        context.debugViewDetailsPayload = _uiKitViewDebugPayload();
        addTearDown(() => context.debugViewDetailsPayload = null);

        final executor = DefaultCoreCommandExecutor(
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
          desktopWindowScreenshotService: const _SuccessFakeAdapter(),
        );

        final result = await executor.execute(const GetScreenshotsCommand());

        expect(result.ok, isTrue);
        final data = result.data! as Map<String, Object?>;
        expect(data['requestedMode'], 'auto');
        expect(data['actualMode'], 'desktop_window');
        expect(data['captureMode'], 'desktop_window');
        expect(data['captureHints'], isA<Map<String, Object?>>());
        final hints = data['captureHints']! as Map<String, Object?>;
        expect(hints['platformViewsDetected'], isTrue);
        final warnings = data['warnings'] as List<dynamic>?;
        expect(
          warnings?.any(
            (final w) => '$w'.contains('upgraded to desktop_window'),
          ),
          isTrue,
        );
      },
    );

    test('flutter_layer with platform views attaches warnings', () async {
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
      context.debugViewDetailsPayload = _uiKitViewDebugPayload();
      context.debugViewScreenshotsPayload = const <String, Object?>{
        'images': <String>['AQID'],
      };
      addTearDown(() {
        context.debugViewDetailsPayload = null;
        context.debugViewScreenshotsPayload = null;
      });

      final executor = DefaultCoreCommandExecutor(
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
        desktopWindowScreenshotService: const _FlutterLayerCapableFakeAdapter(),
      );

      final result = await executor.execute(
        const GetScreenshotsCommand(mode: ScreenshotMode.flutterLayer),
      );

      expect(result.ok, isTrue);
      final data = result.data! as Map<String, Object?>;
      expect(data['captureMode'], screenshotModeFlutterLayer);
      expect(data['desktopCaptureRetried'], isNull);
      final warnings = data['warnings'] as List<dynamic>?;
      expect(warnings, isNotNull);
      expect(
        warnings!.any((final w) => '$w'.contains('platform view')),
        isTrue,
      );
      expect(data['captureHints'], isA<Map<String, Object?>>());
    });

    test('flutter_layer with Texture only attaches weak warnings', () async {
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
      context.debugViewDetailsPayload = <String, Object?>{
        'widgetTree': <String, Object?>{
          'widgetType': 'Column',
          'children': <Object?>[
            <String, Object?>{
              'widgetType': 'Texture',
              'children': const <Object?>[],
            },
          ],
        },
      };
      context.debugViewScreenshotsPayload = const <String, Object?>{
        'images': <String>['AQID'],
      };
      addTearDown(() {
        context.debugViewDetailsPayload = null;
        context.debugViewScreenshotsPayload = null;
      });

      final executor = DefaultCoreCommandExecutor(
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
        desktopWindowScreenshotService: const _FlutterLayerCapableFakeAdapter(),
      );

      final result = await executor.execute(
        const GetScreenshotsCommand(mode: ScreenshotMode.flutterLayer),
      );

      expect(result.ok, isTrue);
      final data = result.data! as Map<String, Object?>;
      expect(data['captureMode'], screenshotModeFlutterLayer);
      expect(data['desktopCaptureRetried'], isNull);
      expect(data['actualMode'], isNot(equals('desktop_window')));
      final hints = data['captureHints']! as Map<String, Object?>;
      expect(hints['weakSignalsDetected'], isTrue);
      expect(hints['platformViewsDetected'], isFalse);
      final warnings = data['warnings'] as List<dynamic>?;
      expect(warnings?.any((final w) => '$w'.contains('Texture')), isTrue);
    });

    test(
      'desktop failure with platform views puts captureHints in error details',
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
        context.debugViewDetailsPayload = _uiKitViewDebugPayload();
        addTearDown(() => context.debugViewDetailsPayload = null);

        final executor = DefaultCoreCommandExecutor(
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
          desktopWindowScreenshotService: const _AlwaysFailFakeAdapter(),
        );

        final result = await executor.execute(const GetScreenshotsCommand());

        expect(result.ok, isFalse);
        expect(result.data, isNull);
        final details = result.error?.details;
        expect(details, isA<Map>());
        final detailsMap = Map<String, Object?>.from(details! as Map);
        final captureHints = Map<String, Object?>.from(
          (detailsMap['captureHints'] as Map?) ?? const <String, Object?>{},
        );
        expect(captureHints['platformViewsDetected'], isTrue);
      },
    );
  });
}

final class _RetryOnceFakeAdapter
    implements DesktopWindowScreenshotService, VisualCapturePlatformAdapter {
  _RetryOnceFakeAdapter({this.onCapture});

  final void Function()? onCapture;
  var _calls = 0;

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
  bool supportsPlatform(final String effectivePlatform) => true;

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
    onCapture?.call();
    _calls++;
    if (_calls == 1) {
      return null;
    }
    return const DesktopWindowScreenshotCapture(
      images: <String>['AQID'],
      captureMode: 'desktop_window',
    );
  }

  @override
  Future<PermissionBrokerResult> status({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) async => PermissionBrokerResult(
    kind: kind,
    status: PermissionStatus.granted,
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

final class _FlutterLayerCapableFakeAdapter
    implements DesktopWindowScreenshotService, VisualCapturePlatformAdapter {
  const _FlutterLayerCapableFakeAdapter();

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
  String get truthMode => screenshotModeFlutterLayer;

  @override
  bool supportsPlatform(final String effectivePlatform) => true;

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
  }) async => null;

  @override
  Future<PermissionBrokerResult> status({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) async => PermissionBrokerResult(
    kind: kind,
    status: PermissionStatus.granted,
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

final class _SuccessFakeAdapter
    implements DesktopWindowScreenshotService, VisualCapturePlatformAdapter {
  const _SuccessFakeAdapter();

  @override
  String get backend => 'fake_macos';

  @override
  Set<CaptureCapability> get capabilities => const <CaptureCapability>{
    CaptureCapability.desktopWindow,
  };

  @override
  PermissionOwner get owner => PermissionOwner.host;

  @override
  Set<String> get supportedModes => const <String>{screenshotModeDesktopWindow};

  @override
  String get truthMode => screenshotModeDesktopWindow;

  @override
  bool supportsPlatform(final String effectivePlatform) => true;

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
  }) async => const DesktopWindowScreenshotCapture(
    images: <String>['AQID'],
    captureMode: 'desktop_window',
  );

  @override
  Future<PermissionBrokerResult> status({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) async => PermissionBrokerResult(
    kind: kind,
    status: PermissionStatus.granted,
    policy: policy,
    owner: owner,
    backend: backend,
    capabilities: capabilities,
    supportedModes: supportedModes,
    truthMode: truthMode,
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

final class _AlwaysFailFakeAdapter
    implements DesktopWindowScreenshotService, VisualCapturePlatformAdapter {
  const _AlwaysFailFakeAdapter();

  @override
  String get backend => 'fake_macos';

  @override
  Set<CaptureCapability> get capabilities => const <CaptureCapability>{
    CaptureCapability.desktopWindow,
  };

  @override
  PermissionOwner get owner => PermissionOwner.host;

  @override
  Set<String> get supportedModes => const <String>{screenshotModeDesktopWindow};

  @override
  String get truthMode => screenshotModeDesktopWindow;

  @override
  bool supportsPlatform(final String effectivePlatform) => true;

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
  }) async => null;

  @override
  Future<PermissionBrokerResult> status({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) async => PermissionBrokerResult(
    kind: kind,
    status: PermissionStatus.granted,
    policy: policy,
    owner: owner,
    backend: backend,
    capabilities: capabilities,
    supportedModes: supportedModes,
    truthMode: truthMode,
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
