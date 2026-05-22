#!/usr/bin/env dart
// ignore_for_file: do_not_use_environment

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:async/async.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/flutter_mcp_server.dart';
import 'package:flutter_mcp_toolkit_capability_core/flutter_mcp_toolkit_capability_core.dart';
import 'package:stream_channel/stream_channel.dart';

Future<void> main(final List<String> args) async {
  final parsedArgs = argParser.parse(args);
  if (parsedArgs.flag(help)) {
    io.stdout.writeln(argParser.usage);
    io.exit(0);
  }

  await runZonedGuarded(
    () async {
      final VMServiceConfigurationRecord configuration = (
        vmHost: parsedArgs.option(dartVMHost) ?? defaultHost,
        vmPort:
            int.tryParse(parsedArgs.option(dartVMPort) ?? '') ?? defaultPort,
        resourcesSupported: parsedArgs.flag(resourcesSupported),
        imagesSupported: parsedArgs.flag(imagesSupported),
        dumpsSupported: parsedArgs.flag(dumpsSupported),
        logLevel: parsedArgs.option(logLevel) ?? defaultLogLevel,
        environment: parsedArgs.option(environment) ?? defaultEnvironment,
        dynamicRegistrySupported: parsedArgs.flag(dynamicRegistrySupported),
        awaitDndConnection: parsedArgs.flag(awaitDndConnection),
        saveImagesToFiles: parsedArgs.flag(saveImagesToFiles),
        flutterProjectDir: _nonEmptyOption(
          parsedArgs.option(flutterProjectDir),
        ),
        flutterDevice: _nonEmptyOption(parsedArgs.option(flutterDevice)),
        flutterDiscoveryTimeoutMs:
            int.tryParse(parsedArgs.option(flutterDiscoveryTimeoutMs) ?? '') ??
            defaultFlutterDiscoveryTimeoutMs,
      );
      final server = MCPToolkitServer.fromStreamChannel(
        StreamChannel.withCloseGuarantee(io.stdin, io.stdout)
            .transform(StreamChannelTransformer.fromCodec(utf8))
            .transformStream(const LineSplitter())
            .transformStream(
              StreamTransformer.fromHandlers(
                handleData: (final data, final sink) {
                  if (data.trim().isEmpty) {
                    return;
                  }
                  sink.add(data);
                },
              ),
            )
            .transformSink(
              StreamSinkTransformer.fromHandlers(
                handleData: (final data, final sink) {
                  sink.add('$data\n');
                },
              ),
            ),
        configuration: configuration,
      );
      await server.capabilityHost.registerCapability(const FmtCapability());
      await server.handleSetLevel(
        SetLevelRequest(
          level: switch (configuration.logLevel) {
            'debug' => LoggingLevel.debug,
            'info' => LoggingLevel.info,
            'notice' => LoggingLevel.notice,
            'warning' => LoggingLevel.warning,
            'error' => LoggingLevel.error,
            'critical' => LoggingLevel.critical,
            'alert' => LoggingLevel.alert,
            'emergency' => LoggingLevel.emergency,
            _ => LoggingLevel.critical,
          },
        ),
      );
    },
    (final e, final s) {
      io.stderr
        ..writeln('Error: $e')
        ..writeln('Stack trace: $s');
    },
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, final value) {
        io.stderr.writeln('Print intercepted: $value');
      },
    ),
  );
}

String? _nonEmptyOption(final String? value) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

final argParser = ArgParser(allowTrailingOptions: false)
  ..addOption(
    dartVMHost,
    defaultsTo: defaultHost,
    help: 'Host for Dart VM connection',
  )
  ..addOption(
    dartVMPort,
    defaultsTo: '$defaultPort',
    help: 'Port for Dart VM connection',
  )
  ..addFlag(
    resourcesSupported,
    defaultsTo: true,
    help: 'Enable resources support for widget tree and screenshots',
  )
  ..addFlag(
    imagesSupported,
    defaultsTo: true,
    help: 'Enable images support for screenshots',
  )
  ..addFlag(
    dynamicRegistrySupported,
    help: 'Enable dynamic registry support',
    defaultsTo: true,
  )
  ..addFlag(
    awaitDndConnection,
    help:
        'Await until DND connection is established. '
        'Will block server startup until DND is connected. '
        "This is workaround for MCP Clients which don't "
        'support tools updates. '
        "Important: some clients doesn't support it. "
        'Use with caution. (disable for Windsurf, works with Cursor)',
  )
  ..addFlag(dumpsSupported, help: 'Enable debug dump operations')
  ..addFlag(
    saveImagesToFiles,
    help:
        'Save captured images as files in temporal folder instead of'
        ' returning base64 data',
  )
  ..addOption(
    flutterProjectDir,
    help:
        'Optional Flutter project directory used for machine discovery '
        '(flutter attach --machine)',
  )
  ..addOption(
    flutterDevice,
    help:
        'Optional Flutter device for machine discovery '
        '(for example: chrome)',
  )
  ..addOption(
    flutterDiscoveryTimeoutMs,
    defaultsTo: '$defaultFlutterDiscoveryTimeoutMs',
    help:
        'Timeout in milliseconds for flutter machine discovery '
        '(flutter attach --machine)',
  )
  ..addOption(
    logLevel,
    defaultsTo: defaultLogLevel,
    help:
        'Logging level '
        '(debug|info|notice|warning|error|critical|alert|emergency)',
  )
  ..addOption(
    environment,
    defaultsTo: defaultEnvironment,
    help: 'Environment mode (development|production)',
  )
  ..addFlag(help, abbr: 'h', help: 'Show usage text');

const defaultHost = 'localhost';
const defaultPort = 8181;
const defaultLogLevel = 'critical';
const defaultEnvironment = 'production';
const dartVMHost = 'dart-vm-host';
const dartVMPort = 'dart-vm-port';
const resourcesSupported = 'resources';
const imagesSupported = 'images';
const dumpsSupported = 'dumps';
const logLevel = 'log-level';
const environment = 'environment';
const help = 'help';
const dynamicRegistrySupported = 'dynamics';
const awaitDndConnection = 'await-dnd';
const saveImagesToFiles = 'save-images';
const flutterProjectDir = 'flutter-project-dir';
const flutterDevice = 'flutter-device';
const flutterDiscoveryTimeoutMs = 'flutter-discovery-timeout-ms';
const defaultFlutterDiscoveryTimeoutMs = 2500;
