import 'dart:async';

import 'package:dart_mcp/client.dart';

import '../mcp_models.dart';
import '../mcp_toolkit_binding.dart';

const flutterPermissionSupportedKindsResource = 'permissions_supported_kinds';
const flutterPermissionStatusTool = 'permission_status';
const flutterPermissionRequestTool = 'request_permission';
const flutterPermissionOpenSettingsTool = 'open_permission_settings';

final class MCPPermissionResult {
  const MCPPermissionResult({
    required this.kind,
    required this.status,
    this.owner = 'app',
    this.backend = 'app_bridge',
    this.capabilities = const <String>[],
    this.supportedModes = const <String>[],
    this.actualMode,
    this.truthMode,
    this.fallbackReason,
    this.message,
    this.details = const <String, Object?>{},
    this.canRequest = false,
    this.canOpenSettings = false,
  });

  final String kind;
  final String status;
  final String owner;
  final String backend;
  final List<String> capabilities;
  final List<String> supportedModes;
  final String? actualMode;
  final String? truthMode;
  final String? fallbackReason;
  final String? message;
  final Map<String, Object?> details;
  final bool canRequest;
  final bool canOpenSettings;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind,
    'status': status,
    'owner': owner,
    'backend': backend,
    'capabilities': capabilities,
    'supportedModes': supportedModes,
    'actualMode': actualMode,
    'truthMode': truthMode,
    'fallbackReason': fallbackReason,
    'message': message,
    'details': details,
    'canRequest': canRequest,
    'canOpenSettings': canOpenSettings,
  };
}

abstract interface class MCPPermissionDelegate {
  Iterable<String> listSupportedPermissionKinds();

  FutureOr<MCPPermissionResult> getPermissionStatus({required String kind});

  FutureOr<MCPPermissionResult> requestPermission({required String kind});

  FutureOr<MCPPermissionResult> openPermissionSettings({required String kind});
}

Set<MCPCallEntry> getFlutterMcpPermissionEntries({
  required final MCPPermissionDelegate delegate,
}) => <MCPCallEntry>{
  _SupportedKindsResource(delegate: delegate),
  _PermissionStatusEntry(delegate: delegate),
  _PermissionRequestEntry(delegate: delegate),
  _PermissionOpenSettingsEntry(delegate: delegate),
};

extension MCPToolkitPermissionBindingExtension on MCPToolkitBinding {
  void initializeFlutterPermissionToolkit({
    required final MCPPermissionDelegate delegate,
  }) => unawaited(
    addEntries(entries: getFlutterMcpPermissionEntries(delegate: delegate)),
  );
}

extension type _SupportedKindsResource._(MCPCallEntry entry)
    implements MCPCallEntry {
  factory _SupportedKindsResource({
    required final MCPPermissionDelegate delegate,
  }) {
    final entry = MCPCallEntry.resource(
      handler: (final parameters) {
        final kinds = delegate.listSupportedPermissionKinds().toList(
          growable: false,
        );
        return MCPCallResult(
          message: 'Supported permission kinds.',
          parameters: <String, dynamic>{'supportedKinds': kinds},
        );
      },
      definition: MCPResourceDefinition(
        name: flutterPermissionSupportedKindsResource,
        description: 'List permission kinds supported by the app bridge.',
        mimeType: 'application/json',
      ),
    );
    return _SupportedKindsResource._(entry);
  }
}

extension type _PermissionStatusEntry._(MCPCallEntry entry)
    implements MCPCallEntry {
  factory _PermissionStatusEntry({
    required final MCPPermissionDelegate delegate,
  }) {
    final entry = MCPCallEntry.tool(
      handler: (final parameters) async {
        final kind = parameters['kind'] ?? 'visual_capture';
        final payload = await delegate.getPermissionStatus(kind: kind);
        return MCPCallResult(
          message: payload.message ?? 'Permission status read.',
          parameters: payload.toJson(),
        );
      },
      definition: MCPToolDefinition(
        name: flutterPermissionStatusTool,
        description: 'Read app-side permission status.',
        inputSchema: ObjectSchema(
          properties: {
            'kind': StringSchema(description: 'Permission kind to inspect'),
          },
        ),
      ),
    );
    return _PermissionStatusEntry._(entry);
  }
}

extension type _PermissionRequestEntry._(MCPCallEntry entry)
    implements MCPCallEntry {
  factory _PermissionRequestEntry({
    required final MCPPermissionDelegate delegate,
  }) {
    final entry = MCPCallEntry.tool(
      handler: (final parameters) async {
        final kind = parameters['kind'] ?? 'visual_capture';
        final payload = await delegate.requestPermission(kind: kind);
        return MCPCallResult(
          message: payload.message ?? 'Permission request completed.',
          parameters: payload.toJson(),
        );
      },
      definition: MCPToolDefinition(
        name: flutterPermissionRequestTool,
        description: 'Request an app-side permission.',
        inputSchema: ObjectSchema(
          properties: {
            'kind': StringSchema(description: 'Permission kind to request'),
          },
        ),
      ),
    );
    return _PermissionRequestEntry._(entry);
  }
}

extension type _PermissionOpenSettingsEntry._(MCPCallEntry entry)
    implements MCPCallEntry {
  factory _PermissionOpenSettingsEntry({
    required final MCPPermissionDelegate delegate,
  }) {
    final entry = MCPCallEntry.tool(
      handler: (final parameters) async {
        final kind = parameters['kind'] ?? 'visual_capture';
        final payload = await delegate.openPermissionSettings(kind: kind);
        return MCPCallResult(
          message: payload.message ?? 'Opened permission settings.',
          parameters: payload.toJson(),
        );
      },
      definition: MCPToolDefinition(
        name: flutterPermissionOpenSettingsTool,
        description: 'Open app-side permission settings.',
        inputSchema: ObjectSchema(
          properties: {
            'kind': StringSchema(
              description: 'Permission kind to open in settings',
            ),
          },
        ),
      ),
    );
    return _PermissionOpenSettingsEntry._(entry);
  }
}
