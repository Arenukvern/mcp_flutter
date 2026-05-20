// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// Server-side command catalog: schema builders, arg parsers, command factory.
// Pure command classes live in mcp_shared_core/lib/src/commands/core_commands.dart.

import 'package:mcp_shared_core/mcp_shared_core.dart';

final class CommandCatalog {
  CommandCatalog._();

  static final CommandCatalog instance = CommandCatalog._();

  late final Map<String, CommandSpec> _byName = {
    for (final spec in _buildSpecs()) spec.name: spec,
  };

  final List<Map<String, Object?>> defaultSnapshotPlan =
      const <Map<String, Object?>>[
        <String, Object?>{'name': 'status', 'args': <String, Object?>{}},
        <String, Object?>{
          'name': 'discover_debug_apps',
          'args': <String, Object?>{},
        },
        <String, Object?>{'name': 'get_vm', 'args': <String, Object?>{}},
        <String, Object?>{
          'name': 'get_extension_rpcs',
          'args': <String, Object?>{},
        },
        <String, Object?>{
          'name': 'get_app_errors',
          'args': <String, Object?>{'count': 4},
        },
        <String, Object?>{
          'name': 'get_view_details',
          'args': <String, Object?>{},
        },
      ];

  List<CommandSpec> get commands {
    final all = _byName.values.toList()
      ..sort((final a, final b) => a.name.compareTo(b.name));
    return all;
  }

  CoreCommand buildCommand(final String name, final Map<String, Object?> args) {
    final spec = _byName[name];
    if (spec == null) {
      throw ArgumentError('Unsupported command: $name');
    }
    _validateUnknownKeys(spec: spec, args: args);
    return spec.build(args);
  }

  CapabilitiesModel capabilities({
    required final CoreRuntimeConfiguration configuration,
  }) {
    final commandSummaries = commands
        .map(
          (final spec) => {
            'name': spec.name,
            'requiresVm': spec.requiresVm,
            'supportsWatch': spec.supportsWatch,
            'mcpExposed': spec.mcpExposed,
          },
        )
        .toList();

    return CapabilitiesModel(
      protocolVersion: kFlutterMcpProtocolVersion,
      schemaVersion: kCommandCatalogSchemaVersion,
      commands: commandSummaries,
      providers: const {
        'summaryProviders': <String>['none', 'openai'],
      },
      features: {
        'exec': true,
        'schema': true,
        'capabilities': true,
        'serve': true,
        'watch': true,
        'sessions': true,
        'snapshot': true,
        'bundle': true,
        'stateLocking': true,
        'resources': configuration.resourcesSupported,
        'images': configuration.imagesSupported,
        'dumps': configuration.dumpsSupported,
        'dynamicRegistry': configuration.dynamicRegistrySupported,
      },
      limits: {
        'defaultWatchIntervalMs': 1000,
        'defaultErrorCount': 4,
        'defaultSnapshotCommands': defaultSnapshotPlan.length,
      },
    );
  }

  bool contains(final String name) => _byName.containsKey(name);

  Map<String, Object?> schema({final String? name}) {
    if (name != null && name.isNotEmpty) {
      final spec = _byName[name];
      if (spec == null) {
        throw ArgumentError('Unknown command for schema lookup: $name');
      }
      return {
        'schemaVersion': kCommandCatalogSchemaVersion,
        'command': spec.toJson(),
      };
    }

    return {
      'schemaVersion': kCommandCatalogSchemaVersion,
      'commands': commands.map((final spec) => spec.toJson()).toList(),
    };
  }

  CommandSpec? specFor(final String name) => _byName[name];

  List<CommandSpec> _buildSpecs() {
    final specs = <CommandSpec>[
      CommandSpec(
        name: 'connect',
        description: 'Connect to Flutter VM service.',
        inputSchema: _objectSchema(
          properties: {
            'mode': _stringSchema(
              enumValues: const <String>['auto', 'manual', 'uri'],
            ),
            'targetId': _stringSchema(
              description:
                  'Preferred target identifier as full VM websocket URI. '
                  'Copy from discover_debug_apps/availableTargets. '
                  'Do not use host:port.',
            ),
            'uri': _stringSchema(
              description:
                  'Full websocket VM URI. Safest selector: paste app.debugPort.wsUri exactly.',
            ),
            'host': _stringSchema(),
            'port': _intSchema(),
            'force': _boolSchema(defaultValue: false),
          },
        ),
        outputSchema: _objectSchema(
          properties: {
            'connected': _boolSchema(),
            'reusedConnection': _boolSchema(),
            'endpoint': _stringSchema(),
          },
        ),
        requiresVm: false,
        supportsWatch: false,
        mcpExposed: false,
        build: (final args) => ConnectCommand(
          mode: _parseConnectionMode(
            _stringArg(args, 'mode', fallback: 'auto'),
          ),
          targetId: _nullableStringArg(args, 'targetId', alias: 'target-id'),
          uri: _nullableStringArg(args, 'uri'),
          host: _nullableStringArg(args, 'host'),
          port: _nullableIntArg(args, 'port'),
          forceReconnect: _boolArg(args, 'force', fallback: false),
        ),
      ),
      CommandSpec(
        name: 'session_start',
        description:
            'Create a persistent logical session bound to an endpoint.',
        inputSchema: _objectSchema(
          properties: {
            'mode': _stringSchema(
              enumValues: const <String>['auto', 'manual', 'uri'],
            ),
            'targetId': _stringSchema(
              description:
                  'Preferred target identifier as full VM websocket URI. '
                  'Copy from discover_debug_apps/availableTargets. '
                  'Do not use host:port.',
            ),
            'uri': _stringSchema(
              description:
                  'Full websocket VM URI. Safest selector: paste app.debugPort.wsUri exactly.',
            ),
            'host': _stringSchema(),
            'port': _intSchema(),
            'force': _boolSchema(defaultValue: false),
            'sessionId': _stringSchema(),
          },
        ),
        outputSchema: _objectSchema(
          properties: {
            'sessionId': _stringSchema(),
            'endpoint': _stringSchema(),
            'mode': _stringSchema(),
            'connected': _boolSchema(),
          },
          required: const <String>[
            'sessionId',
            'endpoint',
            'mode',
            'connected',
          ],
        ),
        requiresVm: false,
        supportsWatch: false,
        mcpExposed: false,
        build: (final args) => SessionStartCommand(
          mode: _parseConnectionMode(
            _stringArg(args, 'mode', fallback: 'auto'),
          ),
          targetId: _nullableStringArg(args, 'targetId', alias: 'target-id'),
          uri: _nullableStringArg(args, 'uri'),
          host: _nullableStringArg(args, 'host'),
          port: _nullableIntArg(args, 'port'),
          forceReconnect: _boolArg(args, 'force', fallback: false),
          sessionId: _nullableStringArg(args, 'sessionId', alias: 'session-id'),
        ),
      ),
      CommandSpec(
        name: 'session_exec',
        description: 'Execute a command in an existing session context.',
        inputSchema: _objectSchema(
          properties: {
            'sessionId': _stringSchema(),
            'command': _stringSchema(),
            'arguments': _objectSchema(additionalProperties: true),
          },
          required: const <String>['command'],
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: false,
        supportsWatch: false,
        mcpExposed: false,
        build: (final args) {
          final targetName = _stringArg(args, 'command', fallback: 'status');
          final targetArgs = _mapArg(args, 'arguments');
          return SessionExecCommand(
            sessionId: _nullableStringArg(
              args,
              'sessionId',
              alias: 'session-id',
            ),
            command: buildCommand(targetName, targetArgs),
          );
        },
      ),
      CommandSpec(
        name: 'session_end',
        description: 'Terminate a persisted session record.',
        inputSchema: _objectSchema(
          properties: {
            'sessionId': _stringSchema(),
            'targetDomain': _stringSchema(),
          },
        ),
        outputSchema: _objectSchema(
          properties: {
            'sessionId': _stringSchema(),
            'ended': _boolSchema(),
            'remainingSessions': _intSchema(),
          },
        ),
        requiresVm: false,
        supportsWatch: false,
        mcpExposed: false,
        build: (final args) => SessionEndCommand(
          sessionId: _nullableStringArg(args, 'sessionId', alias: 'session-id'),
        ),
      ),
      CommandSpec(
        name: 'diagnose',
        description: 'Run a compact diagnostics bundle across core commands.',
        inputSchema: _objectSchema(
          properties: {'includeViewDetails': _boolSchema(defaultValue: false)},
        ),
        outputSchema: _objectSchema(
          properties: {
            'steps': _arraySchema(items: _objectSchema()),
            'summary': _objectSchema(),
          },
        ),
        requiresVm: false,
        supportsWatch: false,
        mcpExposed: false,
        build: (final args) => DiagnoseCommand(
          includeViewDetails: _boolArg(
            args,
            'includeViewDetails',
            alias: 'include-view-details',
            fallback: false,
          ),
        ),
      ),
      CommandSpec(
        name: 'watch',
        description:
            'Run a command repeatedly and emit command_result snapshots.',
        inputSchema: _objectSchema(
          properties: {
            'sessionId': _stringSchema(),
            'command': _stringSchema(),
            'arguments': _objectSchema(additionalProperties: true),
            'intervalMs': _intSchema(defaultValue: 1000),
            'maxEvents': _intSchema(defaultValue: 0),
            'stopOnError': _boolSchema(defaultValue: false),
          },
          required: const <String>['command'],
        ),
        outputSchema: _objectSchema(
          properties: {
            'event': _stringSchema(),
            'command': _stringSchema(),
            'result': _objectSchema(),
          },
        ),
        requiresVm: false,
        supportsWatch: false,
        mcpExposed: false,
        build: (final args) {
          final targetName = _stringArg(args, 'command', fallback: 'status');
          final targetArgs = _mapArg(args, 'arguments');
          return WatchCommand(
            sessionId: _nullableStringArg(
              args,
              'sessionId',
              alias: 'session-id',
            ),
            command: buildCommand(targetName, targetArgs),
            intervalMs: _intArg(
              args,
              'intervalMs',
              alias: 'interval-ms',
              fallback: 1000,
            ),
            maxEvents: _intArg(
              args,
              'maxEvents',
              alias: 'max-events',
              fallback: 0,
            ),
            stopOnError: _boolArg(
              args,
              'stopOnError',
              alias: 'stop-on-error',
              fallback: false,
            ),
          );
        },
      ),
      CommandSpec(
        name: 'explain_errors',
        description:
            'Classify recent Flutter errors with deterministic causes. '
            'Optional AI summary: summaryProvider `openai` sends diagnostics to OpenAI; '
            'set allowExternalSummary to true to consent.',
        inputSchema: _objectSchema(
          properties: {
            'count': _intSchema(defaultValue: 4),
            'includeSummary': _boolSchema(defaultValue: true),
            'summaryProvider': _stringSchema(defaultValue: 'none'),
            'allowExternalSummary': _boolSchema(defaultValue: false),
          },
        ),
        outputSchema: _objectSchema(
          properties: {
            'message': _stringSchema(),
            'errors': _arraySchema(items: _objectSchema()),
            'causes': _arraySchema(items: _objectSchema()),
            'summary': _stringSchema(nullable: true),
            'summaryStatus': _stringSchema(),
            'summaryReason': _stringSchema(nullable: true),
            'summaryDetail': _stringSchema(nullable: true),
            'summaryProvider': _stringSchema(),
          },
        ),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: false,
        build: (final args) => ExplainErrorsCommand(
          count: _intArg(args, 'count', fallback: 4),
          includeSummary: _boolArg(
            args,
            'includeSummary',
            alias: 'include-summary',
            fallback: true,
          ),
          summaryProvider: _stringArg(
            args,
            'summaryProvider',
            alias: 'summary-provider',
            fallback: 'none',
          ),
          allowExternalSummary: _boolArg(
            args,
            'allowExternalSummary',
            alias: 'allow-external-summary',
            fallback: false,
          ),
        ),
      ),
      CommandSpec(
        name: 'status',
        description: 'Return connection and runtime support status.',
        inputSchema: _objectSchema(),
        outputSchema: _objectSchema(
          properties: {
            'connected': _boolSchema(),
            'activeEndpoint': _stringSchema(nullable: true),
            'stickyEndpoint': _stringSchema(nullable: true),
            'mode': _stringSchema(),
          },
        ),
        requiresVm: false,
        supportsWatch: true,
        mcpExposed: false,
        build: (final args) => const StatusCommand(),
      ),
      CommandSpec(
        name: 'discover_debug_apps',
        description:
            'Discover active Flutter debug targets with canonical VM URIs.',
        inputSchema: _objectSchema(),
        outputSchema: _objectSchema(
          properties: {
            'targets': _arraySchema(
              items: _objectSchema(
                properties: {
                  'targetId': _stringSchema(),
                  'host': _stringSchema(),
                  'port': _intSchema(),
                  'endpoint': _stringSchema(),
                  'dtdUri': _stringSchema(nullable: true),
                  'discoverySource': _stringSchema(),
                  'isSticky': _boolSchema(),
                  'isCurrent': _boolSchema(),
                },
              ),
            ),
            'ports': _arraySchema(items: _intSchema()),
            'count': _intSchema(),
            'diagnostics': _objectSchema(additionalProperties: true),
          },
        ),
        requiresVm: false,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => const DiscoverDebugAppsCommand(),
      ),
      CommandSpec(
        name: 'get_vm',
        description: 'Fetch VM metadata from active Dart VM service.',
        inputSchema: _objectSchema(),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => const GetVmCommand(),
      ),
      CommandSpec(
        name: 'get_extension_rpcs',
        description: 'List extension RPC names from all isolates.',
        inputSchema: _objectSchema(),
        outputSchema: _arraySchema(items: _stringSchema()),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => const GetExtensionRpcsCommand(),
      ),
      CommandSpec(
        name: 'hot_reload_flutter',
        description: 'Run Flutter hot reload through VM service.',
        inputSchema: _objectSchema(
          properties: {'force': _boolSchema(defaultValue: false)},
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => HotReloadFlutterCommand(
          force: _boolArg(args, 'force', fallback: false),
        ),
      ),
      CommandSpec(
        name: 'hot_restart_flutter',
        description: 'Run Flutter hot restart through VM service.',
        inputSchema: _objectSchema(),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => const HotRestartFlutterCommand(),
      ),
      CommandSpec(
        name: 'get_active_ports',
        description: 'Return currently active Flutter debug ports.',
        inputSchema: _objectSchema(),
        outputSchema: _arraySchema(items: _intSchema()),
        requiresVm: false,
        supportsWatch: true,
        mcpExposed: false,
        build: (final args) => const GetActivePortsCommand(),
      ),
      CommandSpec(
        name: 'get_app_errors',
        description: 'Fetch recent app errors captured by toolkit extension.',
        inputSchema: _objectSchema(
          properties: {'count': _intSchema(defaultValue: 4)},
        ),
        outputSchema: _objectSchema(
          properties: {
            'message': _stringSchema(),
            'errors': _arraySchema(
              items: _objectSchema(additionalProperties: true),
            ),
          },
          additionalProperties: true,
        ),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) =>
            GetAppErrorsCommand(count: _intArg(args, 'count', fallback: 4)),
      ),
      CommandSpec(
        name: 'get_screenshots',
        description: 'Collect screenshots for all current Flutter views.',
        inputSchema: _objectSchema(
          properties: {
            'compress': _boolSchema(defaultValue: true),
            'mode': _stringSchema(
              enumValues: ScreenshotMode.values
                  .map((final mode) => mode.wireName)
                  .toList(growable: false),
              defaultValue: ScreenshotMode.auto.wireName,
            ),
            'permissionPolicy': _stringSchema(
              enumValues: PermissionPolicy.values
                  .map((final policy) => policy.wireName)
                  .toList(growable: false),
              defaultValue: PermissionPolicy.checkOnly.wireName,
            ),
          },
        ),
        outputSchema: _objectSchema(
          properties: {
            'images': _arraySchema(items: _stringSchema()),
            'fileUrls': _arraySchema(items: _stringSchema()),
            'captureMode': _stringSchema(),
            'requestedMode': _stringSchema(),
            'actualMode': _stringSchema(),
            'fallbackReason': _stringSchema(),
            'permissionStatus': _stringSchema(),
            'permission': _objectSchema(additionalProperties: true),
            'appName': _stringSchema(),
            'windowId': _intSchema(),
            'windowBounds': _objectSchema(additionalProperties: true),
          },
          additionalProperties: true,
        ),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => GetScreenshotsCommand(
          compress: _boolArg(args, 'compress', fallback: true),
          mode: parseScreenshotMode(args['mode']),
          permissionPolicy: parsePermissionPolicy(args['permissionPolicy']),
        ),
      ),
      CommandSpec(
        name: 'get_view_details',
        description:
            'Read detailed Flutter view metrics and widget tree information.',
        inputSchema: _objectSchema(),
        outputSchema: _objectSchema(
          properties: {
            'message': _stringSchema(),
            'details': _arraySchema(
              items: _objectSchema(additionalProperties: true),
            ),
            'widgetTree': _objectSchema(additionalProperties: true),
            'summary': _objectSchema(additionalProperties: true),
          },
          additionalProperties: true,
        ),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => const GetViewDetailsCommand(),
      ),
      CommandSpec(
        name: 'inspect_widget_at_point',
        description:
            'Inspect the deepest widget/render node at global logical (x,y).',
        inputSchema: _objectSchema(
          properties: {
            'x': _intSchema(),
            'y': _intSchema(),
            'viewId': _intSchema(),
          },
          required: const <String>['x', 'y'],
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => InspectWidgetAtPointCommand(
          x: _intArg(args, 'x', fallback: 0),
          y: _intArg(args, 'y', fallback: 0),
          viewId: _nullableIntArg(args, 'viewId', alias: 'view-id'),
        ),
      ),
      CommandSpec(
        name: 'capture_ui_snapshot',
        description:
            'Capture screenshot(s), view details, and app errors in one bundle.',
        inputSchema: _objectSchema(
          properties: {
            'errorsCount': _intSchema(defaultValue: 4),
            'compress': _boolSchema(defaultValue: true),
            'includeViewDetails': _boolSchema(defaultValue: true),
            'includeErrors': _boolSchema(defaultValue: true),
            'screenshotMode': _stringSchema(
              enumValues: ScreenshotMode.values
                  .map((final mode) => mode.wireName)
                  .toList(growable: false),
              defaultValue: ScreenshotMode.auto.wireName,
            ),
            'permissionPolicy': _stringSchema(
              enumValues: PermissionPolicy.values
                  .map((final policy) => policy.wireName)
                  .toList(growable: false),
              defaultValue: PermissionPolicy.checkOnly.wireName,
            ),
          },
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => CaptureUiSnapshotCommand(
          errorsCount: _intArg(args, 'errorsCount', fallback: 4),
          compress: _boolArg(args, 'compress', fallback: true),
          includeViewDetails: _boolArg(
            args,
            'includeViewDetails',
            alias: 'include-view-details',
            fallback: true,
          ),
          includeErrors: _boolArg(
            args,
            'includeErrors',
            alias: 'include-errors',
            fallback: true,
          ),
          screenshotMode: parseScreenshotMode(args['screenshotMode']),
          permissionPolicy: parsePermissionPolicy(args['permissionPolicy']),
        ),
      ),
      CommandSpec(
        name: 'semantic_snapshot',
        description:
            'Get compact semantic tree of interactive widgets with stable refs '
            'usable by interaction tools (tap_widget, enter_text, etc.). '
            'Call this before any interaction tool to get fresh refs.',
        inputSchema: _objectSchema(),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => const SemanticSnapshotCommand(),
      ),
      CommandSpec(
        name: 'tap_widget',
        description:
            'Tap a widget identified by ref from semantic_snapshot. '
            'Refs are session-scoped to the most recent semantic_snapshot call.',
        inputSchema: _objectSchema(
          properties: {
            'ref': _stringSchema(
              description: 'Widget ref from semantic_snapshot (e.g. "s_0").',
            ),
            'snapshotId': _intSchema(
              description:
                  'Optional: snapshot_id returned by most recent '
                  'semantic_snapshot. If provided and stale, the call fails '
                  'with stale_snapshot.',
            ),
          },
          required: const <String>['ref'],
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) => TapWidgetCommand(
          ref: _stringArg(args, 'ref', fallback: ''),
          snapshotId: _nullableIntArg(args, 'snapshotId', alias: 'snapshot-id'),
        ),
      ),
      CommandSpec(
        name: 'enter_text',
        description:
            'Enter text into a text field identified by ref from '
            'semantic_snapshot. Taps the field to focus before typing.',
        inputSchema: _objectSchema(
          properties: {
            'ref': _stringSchema(description: 'Text field ref.'),
            'text': _stringSchema(description: 'Text to enter.'),
            'snapshotId': _intSchema(
              description:
                  'Optional: snapshot_id returned by most recent '
                  'semantic_snapshot. If provided and stale, the call fails '
                  'with stale_snapshot.',
            ),
          },
          required: const <String>['ref', 'text'],
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) => EnterTextCommand(
          ref: _stringArg(args, 'ref', fallback: ''),
          text: _stringArg(args, 'text', fallback: ''),
          snapshotId: _nullableIntArg(args, 'snapshotId', alias: 'snapshot-id'),
        ),
      ),
      CommandSpec(
        name: 'scroll',
        description:
            'Scroll to reveal content in a direction. "down" reveals content '
            'below (finger swipes up); "up" reveals content above. Matches '
            'Playwright and user language ("scroll down to see the footer").',
        inputSchema: _objectSchema(
          properties: {
            'direction': _stringSchema(
              enumValues: const <String>['up', 'down', 'left', 'right'],
            ),
            'ref': _stringSchema(description: 'Optional ref to scroll from.'),
            'distance': _intSchema(defaultValue: 300),
            'snapshotId': _intSchema(
              description:
                  'Optional: snapshot_id returned by most recent '
                  'semantic_snapshot. If provided and stale, the call fails '
                  'with stale_snapshot.',
            ),
          },
          required: const <String>['direction'],
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) {
          final distance = _nullableIntArg(args, 'distance');
          return ScrollCommand(
            direction: _stringArg(args, 'direction', fallback: 'down'),
            ref: _nullableStringArg(args, 'ref'),
            distance: (distance ?? 300).toDouble(),
            snapshotId: _nullableIntArg(
              args,
              'snapshotId',
              alias: 'snapshot-id',
            ),
          );
        },
      ),
      CommandSpec(
        name: 'long_press',
        description: 'Long-press a widget identified by ref.',
        inputSchema: _objectSchema(
          properties: {
            'ref': _stringSchema(description: 'Widget ref.'),
            'snapshotId': _intSchema(
              description:
                  'Optional: snapshot_id returned by most recent '
                  'semantic_snapshot. If provided and stale, the call fails '
                  'with stale_snapshot.',
            ),
          },
          required: const <String>['ref'],
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) => LongPressCommand(
          ref: _stringArg(args, 'ref', fallback: ''),
          snapshotId: _nullableIntArg(args, 'snapshotId', alias: 'snapshot-id'),
        ),
      ),
      CommandSpec(
        name: 'swipe',
        description:
            'Swipe to reveal content in a direction (higher pointer velocity '
            'than scroll; used for flings). "down" reveals content below.',
        inputSchema: _objectSchema(
          properties: {
            'direction': _stringSchema(
              enumValues: const <String>['up', 'down', 'left', 'right'],
            ),
            'ref': _stringSchema(description: 'Optional ref to swipe from.'),
            'distance': _intSchema(defaultValue: 300),
            'snapshotId': _intSchema(
              description:
                  'Optional: snapshot_id returned by most recent '
                  'semantic_snapshot. If provided and stale, the call fails '
                  'with stale_snapshot.',
            ),
          },
          required: const <String>['direction'],
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) {
          final distance = _nullableIntArg(args, 'distance');
          return SwipeCommand(
            direction: _stringArg(args, 'direction', fallback: 'up'),
            ref: _nullableStringArg(args, 'ref'),
            distance: (distance ?? 300).toDouble(),
            snapshotId: _nullableIntArg(
              args,
              'snapshotId',
              alias: 'snapshot-id',
            ),
          );
        },
      ),
      CommandSpec(
        name: 'drag',
        description: 'Drag from one widget to another, identified by refs.',
        inputSchema: _objectSchema(
          properties: {
            'fromRef': _stringSchema(description: 'Source widget ref.'),
            'toRef': _stringSchema(description: 'Target widget ref.'),
            'snapshotId': _intSchema(
              description:
                  'Optional: snapshot_id returned by most recent '
                  'semantic_snapshot. If provided and stale, the call fails '
                  'with stale_snapshot.',
            ),
          },
          required: const <String>['fromRef', 'toRef'],
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) => DragCommand(
          fromRef: _stringArg(args, 'fromRef', fallback: ''),
          toRef: _stringArg(args, 'toRef', fallback: ''),
          snapshotId: _nullableIntArg(args, 'snapshotId', alias: 'snapshot-id'),
        ),
      ),
      CommandSpec(
        name: 'hot_reload_and_capture',
        description:
            'Hot reload then capture screenshot + semantic snapshot + errors '
            'in a single call. Tight edit-preview cycle for AI iteration.',
        inputSchema: _objectSchema(
          properties: {
            'compress': _boolSchema(defaultValue: true),
            'includeSemantics': _boolSchema(defaultValue: true),
            'includeErrors': _boolSchema(defaultValue: true),
            'errorsCount': _intSchema(defaultValue: 4),
          },
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) => HotReloadAndCaptureCommand(
          compress: _boolArg(args, 'compress', fallback: true),
          includeSemantics: _boolArg(
            args,
            'includeSemantics',
            alias: 'include-semantics',
            fallback: true,
          ),
          includeErrors: _boolArg(
            args,
            'includeErrors',
            alias: 'include-errors',
            fallback: true,
          ),
          errorsCount: _intArg(args, 'errorsCount', fallback: 4),
        ),
      ),
      CommandSpec(
        name: 'evaluate_dart_expression',
        description:
            'Evaluate a Dart expression in the running app isolate. '
            'Returns the result of the expression as text.',
        inputSchema: _objectSchema(
          properties: {
            'expression': _stringSchema(
              description: 'Dart expression (e.g. "MyClass.instance.value").',
            ),
            'libraryUri': _stringSchema(
              nullable: true,
              description:
                  'Optional library URI for evaluation scope '
                  '(e.g. package:myapp/main.dart). Defaults to root library.',
            ),
          },
          required: const <String>['expression'],
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) => EvaluateDartExpressionCommand(
          expression: _stringArg(args, 'expression', fallback: ''),
          libraryUri: _nullableStringArg(args, 'libraryUri'),
        ),
      ),
      CommandSpec(
        name: 'get_recent_logs',
        description:
            'Get recent print() and debugPrint() output from the running app.',
        inputSchema: _objectSchema(
          properties: {'count': _intSchema(defaultValue: 50)},
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) =>
            GetRecentLogsCommand(count: _intArg(args, 'count', fallback: 50)),
      ),
      CommandSpec(
        name: 'wait_for',
        description:
            'Block until a UI predicate matches or a timeout elapses, then '
            'return a fresh semantic snapshot. Predicate kinds: text, noText, '
            'time, stable, noError. Replaces sleep+snapshot polling loops.',
        inputSchema: _objectSchema(
          required: const ['predicate'],
          properties: {
            'predicate': _objectSchema(additionalProperties: true),
            // Default 5000, max 30000. Schema advertises the ceiling for
            // clients/MCP introspection; the toolkit is the actual enforcer
            // (`_intArg` does not validate against `maximum`).
            'timeoutMs': const <String, Object?>{
              'type': 'integer',
              'default': 5000,
              'maximum': 30000,
              'minimum': 1,
            },
          },
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) => WaitForCommand(
          predicate: _mapArg(args, 'predicate'),
          timeoutMs: _intArg(args, 'timeoutMs', fallback: 5000),
        ),
      ),
      CommandSpec(
        name: 'press_key',
        description:
            'Synthesize a keyboard key press (down + up). Accepted keys: '
            'Enter, Escape, Tab, Backspace, Delete, Space, '
            'ArrowUp/Down/Left/Right, and single ASCII chars (a-z, 0-9). '
            'Optional modifiers: ctrl, shift, alt, meta.',
        inputSchema: _objectSchema(
          required: const ['key'],
          properties: {
            'key': _stringSchema(),
            'ctrl': _boolSchema(),
            'shift': _boolSchema(),
            'alt': _boolSchema(),
            'meta': _boolSchema(),
          },
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) => PressKeyCommand(
          key: _stringArg(args, 'key', fallback: ''),
          ctrl: _boolArg(args, 'ctrl', fallback: false),
          shift: _boolArg(args, 'shift', fallback: false),
          alt: _boolArg(args, 'alt', fallback: false),
          meta: _boolArg(args, 'meta', fallback: false),
        ),
      ),
      CommandSpec(
        name: 'handle_dialog',
        description:
            'Dismiss the topmost popup/dialog route on the registered '
            'Navigator. Currently only action="dismiss" is supported. '
            'Requires the app to register a navigator key via '
            'MCPToolkitBinding.instance.navigatorKey = key',
        inputSchema: _objectSchema(
          required: const ['action'],
          properties: {'action': _stringSchema()},
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) => HandleDialogCommand(
          action: _stringArg(args, 'action', fallback: 'dismiss'),
        ),
      ),
      CommandSpec(
        name: 'navigate',
        description:
            'Drive the registered Navigator: push a named route, pop the '
            'topmost route, or popUntil a named route. Requires '
            'MCPToolkitBinding.instance.navigatorKey = key on the app.',
        inputSchema: _objectSchema(
          required: const ['action'],
          properties: {
            'action': _stringSchema(),
            'route': _stringSchema(),
            'arguments': _objectSchema(additionalProperties: true),
          },
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) => NavigateCommand(
          action: _stringArg(args, 'action', fallback: 'push'),
          route: _stringArg(args, 'route', fallback: '').isEmpty
              ? null
              : _stringArg(args, 'route', fallback: ''),
          arguments: _mapArg(args, 'arguments').isEmpty
              ? null
              : _mapArg(args, 'arguments'),
        ),
      ),
      CommandSpec(
        name: 'fill_form',
        description:
            'Batch text entry: enters text into multiple fields in one '
            'tool call. Stops on first failure (partial form is worse '
            'than a clean error). Each field requires a fresh ref from '
            'semantic_snapshot. Optional snapshotId is checked against '
            'the first field only — refs that change mid-batch will '
            'surface as a stale_snapshot error from the per-field '
            'enter_text dispatch.',
        inputSchema: _objectSchema(
          required: const ['fields'],
          properties: {
            'fields': const <String, Object?>{
              'type': 'array',
              'items': <String, Object?>{
                'type': 'object',
                'required': <String>['ref', 'text'],
                'properties': <String, Object?>{
                  'ref': <String, Object?>{'type': 'string'},
                  'text': <String, Object?>{'type': 'string'},
                },
              },
            },
            'snapshotId': _intSchema(),
          },
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) {
          final raw = args['fields'];
          final list = raw is List
              ? raw
                    .whereType<Object?>()
                    .map<Map<String, Object?>>((final e) {
                      if (e is Map<String, Object?>) return e;
                      if (e is Map) return e.cast<String, Object?>();
                      return const <String, Object?>{};
                    })
                    .toList(growable: false)
              : const <Map<String, Object?>>[];
          final snapshotIdRaw = _intArg(args, 'snapshotId', fallback: 0);
          return FillFormCommand(
            fields: list,
            snapshotId: snapshotIdRaw == 0 ? null : snapshotIdRaw,
          );
        },
      ),
      CommandSpec(
        name: 'hover',
        description:
            'Synthesize a mouse hover at the centre of a widget identified '
            'by a semantic snapshot ref. Drives MouseRegion.onEnter/onExit '
            'and listeners on PointerHoverEvent. Requires a desktop or web '
            'host (mobile platforms have no hover concept). '
            'Call semantic_snapshot immediately before to get fresh refs. '
            'Pass snapshot_id to detect staleness.',
        inputSchema: _objectSchema(
          required: const ['ref'],
          properties: {'ref': _stringSchema(), 'snapshotId': _intSchema()},
        ),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: false,
        mcpExposed: true,
        build: (final args) {
          final snapshotIdRaw = _intArg(args, 'snapshotId', fallback: 0);
          return HoverCommand(
            ref: _stringArg(args, 'ref', fallback: ''),
            snapshotId: snapshotIdRaw == 0 ? null : snapshotIdRaw,
          );
        },
      ),
      CommandSpec(
        name: 'debug_dump_layer_tree',
        description: 'Run ext.flutter.debugDumpLayerTree.',
        inputSchema: _objectSchema(),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => const DebugDumpLayerTreeCommand(),
      ),
      CommandSpec(
        name: 'debug_dump_semantics_tree',
        description: 'Run ext.flutter.debugDumpSemanticsTreeInTraversalOrder.',
        inputSchema: _objectSchema(),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => const DebugDumpSemanticsTreeCommand(),
      ),
      CommandSpec(
        name: 'debug_dump_render_tree',
        description: 'Run ext.flutter.debugDumpRenderTree.',
        inputSchema: _objectSchema(),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => const DebugDumpRenderTreeCommand(),
      ),
      CommandSpec(
        name: 'debug_dump_focus_tree',
        description: 'Run ext.flutter.debugDumpFocusTree.',
        inputSchema: _objectSchema(),
        outputSchema: _objectSchema(additionalProperties: true),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => const DebugDumpFocusTreeCommand(),
      ),
      CommandSpec(
        name: 'fmt_list_client_tools_and_resources',
        description: 'List app-registered dynamic tools and resources.',
        inputSchema: _objectSchema(),
        outputSchema: _objectSchema(
          properties: {
            'appId': _stringSchema(),
            'tools': _arraySchema(items: _objectSchema()),
            'resources': _arraySchema(items: _objectSchema()),
            'summary': _objectSchema(),
          },
        ),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => const ListClientToolsAndResourcesCommand(),
      ),
      CommandSpec(
        name: 'fmt_client_tool',
        description: 'Execute one dynamic tool by name.',
        inputSchema: _objectSchema(
          properties: {
            'toolName': _stringSchema(),
            'arguments': _objectSchema(additionalProperties: true),
          },
          required: const <String>['toolName'],
        ),
        outputSchema: _objectSchema(
          properties: {
            'message': _stringSchema(),
            'parameters': _objectSchema(additionalProperties: true),
          },
        ),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => RunClientToolCommand(
          toolName: _stringArg(
            args,
            'toolName',
            alias: 'tool-name',
            fallback: '',
          ),
          arguments: _mapArg(args, 'arguments'),
        ),
      ),
      CommandSpec(
        name: 'fmt_client_resource',
        description: 'Read one dynamic resource by URI.',
        inputSchema: _objectSchema(
          properties: {'resourceUri': _stringSchema()},
          required: const <String>['resourceUri'],
        ),
        outputSchema: _objectSchema(
          properties: {
            'uri': _stringSchema(),
            'content': _stringSchema(),
            'mimeType': _stringSchema(),
            'blob': _stringSchema(),
            'isBlob': _boolSchema(),
            'message': _stringSchema(),
            'payload': _objectSchema(additionalProperties: true),
          },
          additionalProperties: true,
        ),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => RunClientResourceCommand(
          resourceUri: _stringArg(
            args,
            'resourceUri',
            alias: 'resource-uri',
            fallback: '',
          ),
        ),
      ),
      CommandSpec(
        name: 'dynamicRegistryStats',
        description: 'Return current dynamic registry counters.',
        inputSchema: _objectSchema(
          properties: {'includeAppDetails': _boolSchema(defaultValue: true)},
        ),
        outputSchema: _objectSchema(
          properties: {
            'toolCount': _intSchema(),
            'resourceCount': _intSchema(),
          },
        ),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: false,
        build: (final args) => DynamicRegistryStatsCommand(
          includeAppDetails: _boolArg(
            args,
            'includeAppDetails',
            alias: 'include-app-details',
            fallback: true,
          ),
        ),
      ),
    ];

    return specs.map(_decorateConnectionSchema).toList();
  }

  static Map<String, Object?> _arraySchema({
    required final Map<String, Object?> items,
  }) => {'type': 'array', 'items': items};

  static Map<String, Object?> _asSchemaProperties(final Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, Object?>();
    }
    return const <String, Object?>{};
  }

  static bool _boolArg(
    final Map<String, Object?> args,
    final String key, {
    required final bool fallback,
    final String? alias,
  }) {
    final value = _findArg(args, key, alias: alias);
    if (value == null) {
      return fallback;
    }
    if (value is bool) {
      return value;
    }
    throw ArgumentError(
      'Invalid type for "$key": expected boolean '
      '(schema path: \$.inputSchema.properties.$key)',
    );
  }

  static Map<String, Object?> _boolSchema({final Object? defaultValue}) => {
    'type': 'boolean',
    'default': ?defaultValue,
  };

  static CommandSpec _decorateConnectionSchema(final CommandSpec spec) {
    final supportsConnectionOverride =
        spec.requiresVm || spec.name == 'watch' || spec.name == 'session_exec';
    if (!supportsConnectionOverride) {
      return spec;
    }

    return CommandSpec(
      name: spec.name,
      description: spec.description,
      inputSchema: withOptionalConnectionOverrideSchema(spec.inputSchema),
      outputSchema: spec.outputSchema,
      requiresVm: spec.requiresVm,
      supportsWatch: spec.supportsWatch,
      mcpExposed: spec.mcpExposed,
      build: spec.build,
    );
  }

  static Object? _findArg(
    final Map<String, Object?> args,
    final String key, {
    final String? alias,
  }) {
    if (args.containsKey(key)) {
      return args[key];
    }
    final nextAlias = alias;
    if (nextAlias != null && args.containsKey(nextAlias)) {
      return args[nextAlias];
    }

    final kebab = _toKebabCase(key);
    if (args.containsKey(kebab)) {
      return args[kebab];
    }

    final camel = _toCamelCase(key);
    if (args.containsKey(camel)) {
      return args[camel];
    }

    return null;
  }

  static int _intArg(
    final Map<String, Object?> args,
    final String key, {
    required final int fallback,
    final String? alias,
  }) {
    final value = _findArg(args, key, alias: alias);
    if (value == null) {
      return fallback;
    }
    return _strictIntArg(value: value, key: key);
  }

  static Map<String, Object?> _intSchema({
    final Object? defaultValue,
    final String? description,
  }) => {
    'type': 'integer',
    'default': ?defaultValue,
    'description': ?description,
  };

  static Map<String, Object?> _mapArg(
    final Map<String, Object?> args,
    final String key,
  ) {
    final value = _findArg(args, key, alias: key);
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, Object?>();
    }
    if (value == null) {
      return const <String, Object?>{};
    }

    throw ArgumentError(
      'Invalid type for "$key": expected object '
      '(schema path: \$.inputSchema.properties.$key)',
    );
  }

  static int? _nullableIntArg(
    final Map<String, Object?> args,
    final String key, {
    final String? alias,
  }) {
    final value = _findArg(args, key, alias: alias);
    if (value == null) {
      return null;
    }
    return _strictIntArg(value: value, key: key);
  }

  static String? _nullableStringArg(
    final Map<String, Object?> args,
    final String key, {
    final String? alias,
  }) {
    final value = _findArg(args, key, alias: alias);
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw ArgumentError(
        'Invalid type for "$key": expected string '
        '(schema path: \$.inputSchema.properties.$key)',
      );
    }
    return value.isEmpty ? null : value;
  }

  static Map<String, Object?> _objectSchema({
    final Map<String, Object?> properties = const <String, Object?>{},
    final List<String> required = const <String>[],
    final bool additionalProperties = false,
  }) => {
    'type': 'object',
    'properties': properties,
    'required': required,
    'additionalProperties': additionalProperties,
  };

  static CoreConnectionMode _parseConnectionMode(final String mode) =>
      switch (mode) {
        'auto' => CoreConnectionMode.auto,
        'manual' => CoreConnectionMode.manual,
        'uri' => CoreConnectionMode.uri,
        _ => throw ArgumentError(
          'Invalid value for "mode": "$mode" '
          r'(schema path: $.inputSchema.properties.mode)',
        ),
      };

  static int _strictIntArg({
    required final Object value,
    required final String key,
  }) => switch (value) {
    final int v => v,
    final num v when v == v.roundToDouble() => v.toInt(),
    _ => throw ArgumentError(
      'Invalid type for "$key": expected integer '
      '(schema path: \$.inputSchema.properties.$key)',
    ),
  };

  static String _stringArg(
    final Map<String, Object?> args,
    final String key, {
    required final String fallback,
    final String? alias,
  }) {
    final value = _findArg(args, key, alias: alias);
    if (value == null) {
      return fallback;
    }
    if (value is! String) {
      throw ArgumentError(
        'Invalid type for "$key": expected string '
        '(schema path: \$.inputSchema.properties.$key)',
      );
    }
    return value.isEmpty ? fallback : value;
  }

  static Map<String, Object?> _stringSchema({
    final String? description,
    final List<String>? enumValues,
    final Object? defaultValue,
    final bool nullable = false,
  }) {
    final type = nullable ? const <String>['string', 'null'] : 'string';
    return {
      'type': type,
      'description': ?description,
      'enum': ?enumValues,
      'default': ?defaultValue,
    };
  }

  static String _toCamelCase(final String value) {
    if (!value.contains('-') && !value.contains('_')) {
      return value;
    }

    final parts = value.split(RegExp('[-_]'));
    if (parts.isEmpty) {
      return value;
    }

    return [
      parts.first,
      ...parts.skip(1).map((final part) {
        if (part.isEmpty) {
          return '';
        }
        return '${part[0].toUpperCase()}${part.substring(1)}';
      }),
    ].join();
  }

  static String _toKebabCase(final String value) {
    final normalized = value
        .replaceAllMapped(
          RegExp('([a-z0-9])([A-Z])'),
          (final match) => '${match.group(1)}-${match.group(2)}',
        )
        .replaceAll('_', '-');
    return normalized.toLowerCase();
  }

  static void _validateUnknownKeys({
    required final CommandSpec spec,
    required final Map<String, Object?> args,
  }) {
    final allowsUnknown = spec.inputSchema['additionalProperties'] == true;
    if (allowsUnknown || args.isEmpty) {
      return;
    }

    final properties = _asSchemaProperties(spec.inputSchema['properties']);
    if (properties.isEmpty) {
      if (args.isNotEmpty) {
        final unknown = args.keys.toList()..sort();
        throw ArgumentError(
          'Unknown argument key(s): ${unknown.join(', ')} '
          '(schema path: \$.commands.${spec.name}.inputSchema.properties)',
        );
      }
      return;
    }

    final acceptedKeys = <String>{};
    for (final key in properties.keys) {
      acceptedKeys
        ..add(key)
        ..add(_toKebabCase(key))
        ..add(_toCamelCase(key));
    }

    final unknownKeys =
        args.keys.where((final key) => !acceptedKeys.contains(key)).toList()
          ..sort();

    if (unknownKeys.isNotEmpty) {
      throw ArgumentError(
        'Unknown argument key(s): ${unknownKeys.join(', ')} '
        '(schema path: \$.commands.${spec.name}.inputSchema.properties)',
      );
    }
  }
}

final class CommandSpec {
  const CommandSpec({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.outputSchema,
    required this.requiresVm,
    required this.supportsWatch,
    required this.mcpExposed,
    required this.build,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final Map<String, Object?> outputSchema;
  final bool requiresVm;
  final bool supportsWatch;
  final bool mcpExposed;
  final CoreCommandFactory build;

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'inputSchema': inputSchema,
    'outputSchema': outputSchema,
    'requiresVm': requiresVm,
    'supportsWatch': supportsWatch,
    'mcpExposed': mcpExposed,
  };
}
