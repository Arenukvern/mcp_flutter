// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';

import 'package:flutter/foundation.dart';

/// An interface for all results returned by MCP Toolkit.
///
/// Value for the parameters should be serialized to JSON.
///
/// For example:
/// ```dart
/// final count = jsonDecodeInt(parameters['count'] ?? '').whenZeroUse(10);
/// final reversedErrors = errorMonitor.errors.take(count).toList();
/// final errors = reversedErrors.map((final e) => e.toJson()).toList();
///
/// final result = OnAppErrorsResult(
///   message: 'Errors found',
///   errors: errors,
/// );
/// ```
extension type const MCPCallResult._(Map<String, dynamic> parameters)
    implements Map<String, dynamic> {
  /// The [parameters] will be merged into json with the [message].
  factory MCPCallResult({
    required final String message,
    required final Map<String, dynamic> parameters,
  }) => MCPCallResult._({'message': message, ...parameters});
}

/// same as [ServiceExtensionCallback] parameters
typedef ServiceExtensionRequestMap = Map<String, String>;

/// A MCP call handler for the MCP call.
///
/// The call can be any request from MCP server.
typedef MCPCallHandler =
    FutureOr<MCPCallResult> Function(ServiceExtensionRequestMap request);

/// A method name for the MCP call.
///
/// It should not contain `ext.domain.` part as
/// it will be added automatically in the [MCPBridgeBinding].
extension type const MCPMethodName(String _value) implements String {}

/// A record for the MCP call entry for type safety.
///
/// Use [MCPCallEntry] to create a new entry.
///
/// This typedef made private to avoid using it instead of [MCPCallEntry].
typedef _MCPCallEntryRecord = MapEntry<MCPMethodName, _MCPCallEntryRecordValue>;

/// A record value for the MCP call entry for type safety.
typedef _MCPCallEntryRecordValue =
    ({
      MCPCallHandler handler,
      MCPToolDefinition? toolDefinition,
      MCPResourceDefinition? resourceDefinition,
    });

/// A base definition for MCP definitions.
extension type const MCPDefinition._(Map<String, dynamic> _value)
    implements Map<String, dynamic> {
  /// The [name], [description] and [params] will be merged into json.
  factory MCPDefinition({
    required final String name,
    required final String description,
    final Map<String, dynamic>? params,
  }) => MCPDefinition._({'name': name, 'description': description, ...?params});

  /// Get the name of this definition
  String get name => _value['name'] as String;

  /// Get the description of this definition
  String get description => _value['description'] as String;
}

/// {@template mcp_tool_definition}
/// Tool definition for MCP registration
///
/// Example with tool definition:
/// ```dart
/// extension type OnAppErrorsEntry._(MCPCallEntry entry) implements MCPCallEntry {
///   factory OnAppErrorsEntry({required final ErrorMonitor errorMonitor}) {
///     final entry = MCPCallEntry(
///       methodName: const MCPMethodName('app_errors'),
///       handler: (final request) => MCPCallResult(
///         message: 'Returns app errors',
///         parameters: {'errors': []},
///       ),
///       toolDefinition: MCPToolDefinition(
///         name: 'app_errors',
///         description: 'Get application errors and diagnostics',
///         inputSchema: {
///           'type': 'object',
///           'properties': {
///             'count': {
///               'type': 'integer',
///               'description': 'Number of errors to retrieve',
///               'default': 10,
///             },
///           },
///         },
///       ),
///     );
///     return OnAppErrorsEntry._(entry);
///   }
/// }
/// ```
/// To call from MCP server, use
/// `ext.{MCPBridgeConfiguration.domainName}.{methodName}`.
///
/// By default it will be constructed as
/// `ext.mcp_toolkit.app_errors`
///
/// {@endtemplate}
extension type const MCPToolDefinition._(MCPDefinition _definition)
    implements MCPDefinition {
  /// The [name], [description] and [inputSchema] will be merged into json.
  factory MCPToolDefinition({
    required final String name,
    required final String description,
    final Map<String, dynamic> inputSchema = const {},
  }) => MCPToolDefinition._(
    MCPDefinition(
      name: name,
      description: description,
      params: {'inputSchema': inputSchema},
    ),
  );
}

/// {@template mcp_resource_definition}
/// Resource definition for MCP registration
///
/// ```dart
/// extension type OnAppStateEntry._(MCPCallEntry entry) implements MCPCallEntry {
///   factory OnAppStateEntry({required final AppState appState}) {
///     final entry = MCPCallEntry(
///       methodName: const MCPMethodName('view_details'),
///       handler: (final request) => MCPCallResult(
///         message: 'Returns view details',
///         parameters: {'details': details},
///       ),
///       resourceDefinition: MCPResourceDefinition(
///         name: 'view_details',
///         description: 'Get view details',
///         mimeType: 'application/json',
///       ),
///     );
///     return OnAppStateEntry._(entry);
///   }
/// }
/// ```
/// this should be constructed as
/// `visual://localhost/view/details`
///
/// {@endtemplate}
extension type const MCPResourceDefinition._(MCPDefinition _definition)
    implements MCPDefinition {
  /// The [name], [description] and [mimeType] will be merged into json.
  factory MCPResourceDefinition({
    required final String name,
    required final String description,
    final String mimeType = 'text/plain',
  }) => MCPResourceDefinition._(
    MCPDefinition(
      name: name,
      description: description,
      params: {'mimeType': mimeType},
    ),
  );
}

/// {@template mcp_call_entry}
/// A MCP call entry.
/// Contains a method name and a handler for the call, with optional
/// tool and resource definitions for automatic MCP server registration.
///
/// {@endtemplate}
///
/// {@macro mcp_tool_definition}
///
/// or with resource definition:
///
/// {@macro mcp_resource_definition}
///
///
extension type const MCPCallEntry._(_MCPCallEntryRecord entry)
    implements _MCPCallEntryRecord {
  /// {@macro mcp_call_entry}
  factory MCPCallEntry.resource({
    required final MCPCallHandler handler,
    required final MCPResourceDefinition definition,
  }) => MCPCallEntry._(
    _MCPCallEntryRecord(MCPMethodName(definition.name), (
      handler: handler,
      toolDefinition: null,
      resourceDefinition: definition,
    )),
  );

  /// {@macro mcp_call_entry}
  factory MCPCallEntry.tool({
    required final MCPCallHandler handler,
    required final MCPToolDefinition definition,
  }) => MCPCallEntry._(
    _MCPCallEntryRecord(MCPMethodName(definition.name), (
      handler: handler,
      toolDefinition: definition,
      resourceDefinition: null,
    )),
  );

  /// Check if this entry has a tool definition
  bool get hasTool => value.toolDefinition != null;

  /// Check if this entry has a resource definition
  bool get hasResource => value.resourceDefinition != null;

  /// Get the resource URI for this entry
  String get resourceUri =>
      'visual://localhost/${entry.key.split('_').join('/')}';
}
