// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_inspector_mcp_server/src/core/capabilities_model.dart';
import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/connection_override.dart';
import 'package:flutter_inspector_mcp_server/src/core/core_types.dart';
import 'package:flutter_inspector_mcp_server/src/core/runtime_version.dart';

typedef CoreCommandFactory = CoreCommand Function(Map<String, Object?> args);

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

final class CommandCatalog {
  CommandCatalog._();

  static final CommandCatalog instance = CommandCatalog._();

  late final Map<String, CommandSpec> _byName = {
    for (final spec in _buildSpecs()) spec.name: spec,
  };

  List<CommandSpec> get commands {
    final all = _byName.values.toList()
      ..sort((final a, final b) {
        return a.name.compareTo(b.name);
      });
    return all;
  }

  CommandSpec? specFor(final String name) => _byName[name];

  bool contains(final String name) => _byName.containsKey(name);

  CoreCommand buildCommand(final String name, final Map<String, Object?> args) {
    final spec = _byName[name];
    if (spec == null) {
      throw ArgumentError('Unsupported command: $name');
    }
    _validateUnknownKeys(spec: spec, args: args);
    return spec.build(args);
  }

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
      providers: {
        'summaryProviders': const <String>['none', 'openai'],
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

  final List<Map<String, Object?>> defaultSnapshotPlan =
      const <Map<String, Object?>>[
        <String, Object?>{'name': 'status', 'args': <String, Object?>{}},
        <String, Object?>{'name': 'get_vm', 'args': <String, Object?>{}},
        <String, Object?>{
          'name': 'get_extension_rpcs',
          'args': <String, Object?>{},
        },
        <String, Object?>{
          'name': 'dynamicRegistryStats',
          'args': <String, Object?>{'includeAppDetails': true},
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
        inputSchema: _objectSchema(properties: {'sessionId': _stringSchema()}),
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
            'Classify recent Flutter errors with deterministic causes.',
        inputSchema: _objectSchema(
          properties: {
            'count': _intSchema(defaultValue: 4),
            'includeSummary': _boolSchema(defaultValue: true),
            'summaryProvider': _stringSchema(defaultValue: 'none'),
          },
        ),
        outputSchema: _objectSchema(
          properties: {
            'message': _stringSchema(),
            'errors': _arraySchema(items: _objectSchema()),
            'causes': _arraySchema(items: _objectSchema()),
            'summary': _stringSchema(nullable: true),
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
          },
        ),
        requiresVm: false,
        supportsWatch: true,
        mcpExposed: false,
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
        mcpExposed: true,
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
            'errors': _arraySchema(items: _objectSchema()),
          },
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
          properties: {'compress': _boolSchema(defaultValue: true)},
        ),
        outputSchema: _objectSchema(
          properties: {
            'images': _arraySchema(items: _stringSchema()),
            'fileUrls': _arraySchema(items: _stringSchema()),
          },
        ),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => GetScreenshotsCommand(
          compress: _boolArg(args, 'compress', fallback: true),
        ),
      ),
      CommandSpec(
        name: 'get_view_details',
        description: 'Read detailed info for all Flutter views.',
        inputSchema: _objectSchema(),
        outputSchema: _objectSchema(
          properties: {
            'message': _stringSchema(),
            'details': _arraySchema(items: _objectSchema()),
          },
        ),
        requiresVm: true,
        supportsWatch: true,
        mcpExposed: true,
        build: (final args) => const GetViewDetailsCommand(),
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
        name: 'listClientToolsAndResources',
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
        name: 'runClientTool',
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
        name: 'runClientResource',
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
          },
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
        mcpExposed: true,
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

  static Map<String, Object?> _stringSchema({
    final String? description,
    final List<String>? enumValues,
    final Object? defaultValue,
    final bool nullable = false,
  }) {
    final type = nullable ? const <String>['string', 'null'] : 'string';
    return {
      'type': type,
      if (description != null) 'description': description,
      if (enumValues != null) 'enum': enumValues,
      if (defaultValue != null) 'default': defaultValue,
    };
  }

  static Map<String, Object?> _intSchema({final Object? defaultValue}) => {
    'type': 'integer',
    if (defaultValue != null) 'default': defaultValue,
  };

  static Map<String, Object?> _boolSchema({final Object? defaultValue}) => {
    'type': 'boolean',
    if (defaultValue != null) 'default': defaultValue,
  };

  static Map<String, Object?> _arraySchema({
    required final Map<String, Object?> items,
  }) => {'type': 'array', 'items': items};

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

  static Map<String, Object?> _asSchemaProperties(final Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, Object?>();
    }
    return const <String, Object?>{};
  }

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

  static String _stringArg(
    final Map<String, Object?> args,
    final String key, {
    final String? alias,
    required final String fallback,
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

  static int _intArg(
    final Map<String, Object?> args,
    final String key, {
    final String? alias,
    required final int fallback,
  }) {
    final value = _findArg(args, key, alias: alias);
    if (value == null) {
      return fallback;
    }
    return _strictIntArg(value: value, key: key);
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

  static bool _boolArg(
    final Map<String, Object?> args,
    final String key, {
    final String? alias,
    required final bool fallback,
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

  static int _strictIntArg({
    required final Object value,
    required final String key,
  }) {
    return switch (value) {
      final int v => v,
      final num v when v == v.roundToDouble() => v.toInt(),
      _ => throw ArgumentError(
        'Invalid type for "$key": expected integer '
        '(schema path: \$.inputSchema.properties.$key)',
      ),
    };
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
          RegExp(r'([a-z0-9])([A-Z])'),
          (final match) => '${match.group(1)}-${match.group(2)}',
        )
        .replaceAll('_', '-');
    return normalized.toLowerCase();
  }

  static CoreConnectionMode _parseConnectionMode(final String mode) {
    return switch (mode) {
      'auto' => CoreConnectionMode.auto,
      'manual' => CoreConnectionMode.manual,
      'uri' => CoreConnectionMode.uri,
      _ => throw ArgumentError(
        'Invalid value for "mode": "$mode" '
        '(schema path: \$.inputSchema.properties.mode)',
      ),
    };
  }
}
