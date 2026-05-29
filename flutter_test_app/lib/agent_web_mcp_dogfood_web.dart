import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:intentcall_webmcp/intentcall_webmcp.dart';
import 'package:web/web.dart' as web;

extension type _ModelContext._(JSObject _) implements JSObject {
  external void registerTool(_WebMcpToolDefinition toolDefinition);
}

extension type _WebMcpToolDefinition._(JSObject _) implements JSObject {
  external factory _WebMcpToolDefinition({
    JSString name,
    JSString description,
    JSAny inputSchema,
    JSFunction execute,
  });
}

@JS('JSON.parse')
external JSAny? _jsonParse(JSString source);

/// Exercises [WebMcpPublishAdapter] hot-sync on web (dogfood).
///
/// Skips tools already registered by [registerAgentWebMcpFromEntries] / JS bootstrap
/// to avoid duplicate `registerTool` names on the same `modelContext`. Execute for
/// tools registered only in JS still routes through `__intentcallWebMcpDartExecute`
/// when [registerAgentWebMcpFromEntries] ran after `addEntries`.
Future<void> wireWebMcpPublishAdapterDogfood(
  final Set<AgentCallEntry> entries,
) async {
  final modelContext = _readModelContext();
  if (modelContext == null || entries.isEmpty) {
    return;
  }

  final registry = InMemoryAgentRegistry();
  final adapter = WebMcpPublishAdapter(
    publish: ({
      required final String name,
      required final String description,
      required final Map<String, Object?> inputSchema,
      required final Future<Map<String, Object?>> Function(
        Map<String, Object?> arguments,
      )
      execute,
    }) {
      if (isAgentWebMcpToolRegistered(name)) {
        return;
      }
      final toolDefinition = _WebMcpToolDefinition(
        name: name.toJS,
        description: description.toJS,
        inputSchema: _jsonParse(jsonEncode(inputSchema).toJS)!,
        execute: ((final JSAny? rawArgs) {
          return execute(_decodeArgs(rawArgs)).then(_encodeMap).toJS;
        }).toJS,
      );
      try {
        modelContext.registerTool(toolDefinition);
      } on Object {
        // Duplicate with JS bootstrap — expected on hot restart.
      }
    },
    unpublish: (_) {
      // WebMCP has no standard unregister; registry detach handles our bookkeeping.
    },
  );

  final runtime = AgentRuntime(registry: registry, adapters: [adapter]);
  await runtime.start();
  for (final entry in entries) {
    final registration = entry.toRegistration();
    if (isAgentWebMcpToolRegistered(registration.qualifiedName)) {
      continue;
    }
    registry.register(registration);
  }
}

_ModelContext? _readModelContext() {
  final navigator = web.window.navigator as JSObject;
  if (!navigator.hasProperty('modelContext'.toJS).toDart) {
    return null;
  }
  final value = navigator.getProperty('modelContext'.toJS);
  if (value == null) {
    return null;
  }
  return value as _ModelContext;
}

Map<String, Object?> _decodeArgs(final JSAny? rawArgs) {
  if (rawArgs == null) {
    return const <String, Object?>{};
  }
  final decoded = jsonDecode(jsonEncode(rawArgs.dartify()));
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.cast<String, Object?>();
  }
  return const <String, Object?>{};
}

Map<String, Object?> _encodeMap(final Map<String, Object?> map) => map;
