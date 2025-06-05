#!/usr/bin/env dart
// ignore_for_file: do_not_use_environment

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:async/async.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/flutter_inspector_mcp_server.dart';
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
      );
      final server = MCPToolkitServer.connect(
        StreamChannel.withCloseGuarantee(io.stdin, io.stdout)
            .transform(StreamChannelTransformer.fromCodec(utf8))
            .transformStream(const LineSplitter())
            .transformSink(
              StreamSinkTransformer.fromHandlers(
                handleData: (final data, final sink) {
                  sink.add('$data\n');
                },
              ),
            ),
        configuration: configuration,
      );
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

final argParser =
    ArgParser(allowTrailingOptions: false)
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
      ..addFlag(dumpsSupported, help: 'Enable debug dump operations')
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
