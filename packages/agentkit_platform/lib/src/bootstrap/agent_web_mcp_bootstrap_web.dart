import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:web/web.dart' as web;

@JS('JSON.parse')
external JSAny? _jsonParse(JSString source);

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

void registerFromEntries(final Set<AgentCallEntry> entries) {
  final modelContext = _readModelContext();
  if (modelContext == null) {
    return;
  }

  for (final entry in entries) {
    final descriptor = entry.toRegistration().descriptor;
    if (descriptor.kind != AgentIntentKind.tool) {
      continue;
    }

    modelContext.registerTool(
      _WebMcpToolDefinition(
        name: descriptor.qualifiedName.toJS,
        description: descriptor.description.toJS,
        inputSchema: _jsonParse(jsonEncode(descriptor.inputSchema).toJS)!,
        execute: ((final JSAny? rawArgs) {
          return _invokeEntry(entry, rawArgs).toJS;
        }).toJS,
      ),
    );
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

Future<JSAny?> _invokeEntry(
  final AgentCallEntry entry,
  final JSAny? rawArgs,
) async {
  final args = _decodeArgs(rawArgs);
  final result = await entry.invokeDirect(args);
  return _encodeResult(result).jsify();
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

Map<String, Object?> _encodeResult(final AgentResult result) {
  if (!result.ok) {
    return <String, Object?>{
      'ok': false,
      'code': result.code,
      'message': result.message,
      if (result.details case final details?) 'details': details,
    };
  }
  return <String, Object?>{'ok': true, ...result.data};
}
