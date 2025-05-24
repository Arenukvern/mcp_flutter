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
typedef _MCPCallEntryRecord = MapEntry<MCPMethodName, MCPCallHandler>;

/// {@template mcp_call_entry}
/// A MCP call entry.
/// Contains a method name and a handler for the call.
///
/// Example:
/// ```dart
/// extension type MCPFlameModuleEntry._(MCPModuleEntryRecord entry)
///     implements MCPModuleEntry {
///   factory MCPFlameModuleEntry({required final Game game}) {
///     final entry = MCPModuleEntryRecord(
///       'game_person_info',
///       (final request) => OnViewDetailsResult(
///         message: 'Returns person info for the game',
///         details: [
///           {'name': game.name},
///         ],
///       ),
///     );
///     return MCPFlameModuleEntry._(entry);
///   }
/// }
/// ```
///
/// To call from MCP server, use
/// `ext.{MCPBridgeConfiguration.domainName}.{methodName}`.
///
/// By default it will be constructed as
/// `ext.mcp_toolkit.game_person_info`.
/// {@endtemplate}
extension type const MCPCallEntry._(_MCPCallEntryRecord entry)
    implements _MCPCallEntryRecord {
  /// {@macro mcp_call_entry}
  factory MCPCallEntry(
    final MCPMethodName methodName,
    final MCPCallHandler handler,
  ) => MCPCallEntry._(_MCPCallEntryRecord(methodName, handler));
}
