// ignore_for_file: unnecessary_async, avoid_catches_without_on_clauses

import 'dart:convert';

import 'package:devtools_mcp_extension/common_imports.dart';
import 'package:devtools_mcp_extension/services/custom_devtools_service.dart';
import 'package:devtools_mcp_extension/services/image_compressor.dart';
import 'package:mcp_dart_forwarding_client/mcp_dart_forwarding_client.dart';

const flutterInspectorName = 'ext.flutter.inspector';
const mcpDevtoolsName = 'ext.mcpdevtools';

class ForwardingRpcListener {
  ForwardingRpcListener({
    required this.forwardingClient,
    required this.devtoolsService,
    required this.customDevtoolsService,
    required this.errorDevtoolsService,
  });

  final ForwardingClient forwardingClient;
  final DartVmDevtoolsService devtoolsService;
  final CustomDevtoolsService customDevtoolsService;
  final ErrorDevtoolsService errorDevtoolsService;
  void init() {
    print('Initializing ForwardingRpcListener');

    forwardingClient
      ..on('connected', () {
        print('ForwardingClient connected to server');
      })
      ..on('disconnected', () {
        print(' disconnected from server');
      })
      ..on('error', (final error) {
        print('ForwardingClient error: $error');
      })
      // Register methods that need to return responses
      ..registerMethod('$flutterInspectorName.getRootWidget', (
        final data,
      ) async {
        print('Handler called: getRootWidget with data: $data');
        final result = await devtoolsService.getRootWidget();
        print('getRootWidget result: ${jsonEncode(result).substring(0, 50)}');
        return result;
      })
      ..registerMethod('$mcpDevtoolsName.hotReload', (final data) async {
        print('Handler called: hotReload with data: $data');
        final result = await customDevtoolsService.hotReload(data);
        print('hotReload result: ${jsonEncode(result).substring(0, 50)}');
        return result;
      })
      ..registerMethod('$mcpDevtoolsName.getAppErrors', (final data) async {
        print('Handler called: getAppErrors with data: $data');
        final result = await errorDevtoolsService.getAppErrors(data);
        print('getAppErrors result: ${jsonEncode(result).substring(0, 50)}');
        return result;
      })
      ..registerMethod('$flutterInspectorName.screenshot', (final data) async {
        print('Handler called: screenshot with data: $data');
        try {
          final screenshot = await devtoolsService.takeScreenshot(data);
          final base64Image = screenshot.data;
          var compressedScreenshot = base64Image is String ? base64Image : '';
          if (base64Image != null) {
            compressedScreenshot = await ImageCompressor.compressBase64Image(
              base64Image: base64Image,
            );
            // Print response info without the full data
            print(
              'Screenshot result - error: ${screenshot.error} '
              'success: ${screenshot.success} data length: ${compressedScreenshot.length}',
            );
          } else {
            print(
              'Screenshot result - error: ${screenshot.error} '
              'success: ${screenshot.success} data: null',
            );
          }

          // Test sending a smaller response to verify communication
          if (!forwardingClient.isConnected()) {
            print('WARNING: Client disconnected, cannot send response');
            return RPCResponse.error('Client disconnected');
          }

          print('Returning screenshot response');
          return compressedScreenshot;
        } catch (e, st) {
          print('Error taking screenshot: $e');
          print('Stack trace: $st');
          return RPCResponse.error('Error taking screenshot: $e');
        }
      });

    for (final extension in freelyForwardingExtensions) {
      forwardingClient.registerMethod(extension, (final data) async {
        print('Handler called: $extension with data: $data');
        await devtoolsService.callServiceExtensionRaw(extension, args: data);
      });
    }

    print('Registered all method handlers');
  }
}
