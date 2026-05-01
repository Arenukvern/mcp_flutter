import 'dart:async';

import 'package:dart_mcp/client.dart';

import '../mcp_models.dart';
import '../mcp_toolkit_binding.dart';

/// {@template flutter_permission_supported_kinds_resource}
/// The resource name for the supported permission kinds.
/// {@endtemplate}
const flutterPermissionSupportedKindsResource = 'permissions_supported_kinds';

/// {@template flutter_permission_status_tool}
/// The tool name for the permission status.
/// {@endtemplate}
const flutterPermissionStatusTool = 'permission_status';

/// {@template flutter_permission_request_tool}
/// The tool name for the permission request.
/// {@endtemplate}
const flutterPermissionRequestTool = 'request_permission';

/// {@template flutter_permission_open_settings_tool}
/// The tool name for the permission open settings.
/// {@endtemplate}
const flutterPermissionOpenSettingsTool = 'open_permission_settings';

/// {@template mcp_permission_result}
/// MCP Permission Result.
/// {@endtemplate}
final class MCPPermissionResult {
  /// {@template mcp_permission_result}
  /// MCP Permission Result.
  /// {@endtemplate}
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

  /// {@template kind}
  /// The kind of permission.
  /// {@endtemplate}
  final String kind;

  /// {@template status}
  /// The status of the permission.
  /// {@endtemplate}
  final String status;

  /// {@template owner}
  /// The owner of the permission.
  /// {@endtemplate}
  final String owner;

  /// {@template backend}
  /// The backend of the permission.
  /// {@endtemplate}
  final String backend;

  /// {@template capabilities}
  /// The capabilities of the permission.
  /// {@endtemplate}
  final List<String> capabilities;

  /// {@template supported_modes}
  /// The supported modes of the permission.
  /// {@endtemplate}
  final List<String> supportedModes;

  /// {@template actual_mode}
  /// The actual mode of the permission.
  /// {@endtemplate}
  final String? actualMode;

  /// {@template truth_mode}
  /// The truth mode of the permission.
  /// {@endtemplate}
  final String? truthMode;

  /// {@template fallback_reason}
  /// The fallback reason of the permission.
  /// {@endtemplate}
  final String? fallbackReason;

  /// {@template message}
  /// The message of the permission.
  /// {@endtemplate}
  final String? message;

  /// {@template details}
  /// The details of the permission.
  /// {@endtemplate}
  final Map<String, Object?> details;

  /// {@template can_request}
  /// Whether the permission can be requested.
  /// {@endtemplate}
  final bool canRequest;

  /// {@template can_open_settings}
  /// Whether the permission can be opened in settings.
  /// {@endtemplate}
  final bool canOpenSettings;

  /// {@template to_json}
  /// Convert the permission result to a JSON object.
  /// {@endtemplate}
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

/// {@template mcp_permission_delegate}
/// MCP Permission Delegate.
/// {@endtemplate}
abstract interface class MCPPermissionDelegate {
  /// {@template list_supported_permission_kinds}
  /// List the supported permission kinds.
  /// {@endtemplate}
  Iterable<String> listSupportedPermissionKinds();

  /// {@template get_permission_status}
  /// Get the status of a permission.
  /// {@endtemplate}
  FutureOr<MCPPermissionResult> getPermissionStatus({
    required final String kind,
  });

  /// {@template request_permission}
  /// Request a permission.
  /// {@endtemplate}
  FutureOr<MCPPermissionResult> requestPermission({required final String kind});

  /// {@template open_permission_settings}
  /// Open the permission settings.
  /// {@endtemplate}
  FutureOr<MCPPermissionResult> openPermissionSettings({
    required final String kind,
  });
}

/// Returns a set of MCPCallEntry objects for
/// the Flutter MCP Permission Toolkit.
Set<MCPCallEntry> getFlutterMcpPermissionEntries({
  required final MCPPermissionDelegate delegate,
}) => <MCPCallEntry>{
  _SupportedKindsResource(delegate: delegate),
  _PermissionStatusEntry(delegate: delegate),
  _PermissionRequestEntry(delegate: delegate),
  _PermissionOpenSettingsEntry(delegate: delegate),
};

/// {@template initialize_flutter_permission_toolkit}
/// Initialize the Flutter MCP Permission Toolkit.
/// {@endtemplate}
extension MCPToolkitPermissionBindingExtension on MCPToolkitBinding {
  /// {@template initialize_flutter_permission_toolkit}
  /// Initialize the Flutter MCP Permission Toolkit.
  /// {@endtemplate}
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
