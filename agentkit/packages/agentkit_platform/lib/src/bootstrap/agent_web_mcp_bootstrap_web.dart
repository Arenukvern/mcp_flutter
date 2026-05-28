import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:web/web.dart' as web;

@JS('JSON.parse')
external JSAny? _jsonParse(final JSString source);

/// Tool names already published to `navigator.modelContext` (Dart bootstrap).
final _webMcpRegisteredToolNames = <String>{};

/// Entries available to [__agentkitWebMcpDartExecute] when JS registered first.
final _entriesByQualifiedName = <String, AgentCallEntry>{};

var _dartExecuteHookInstalled = false;

/// Whether [qualifiedName] was registered by [registerFromEntries].
///
/// Used by dogfood [WebMcpPublishAdapter] to avoid triple registration when
/// generated JS bootstrap and Dart bootstrap both run (see web eval doc).
bool isAgentWebMcpToolRegistered(final String qualifiedName) =>
    _webMcpRegisteredToolNames.contains(qualifiedName);

extension type _ModelContext._(JSObject _) implements JSObject {
  external void registerTool(final _WebMcpToolDefinition toolDefinition);
}

extension type _WebMcpToolDefinition._(JSObject _) implements JSObject {
  external factory _WebMcpToolDefinition({
    final JSString name,
    final JSString description,
    final JSAny inputSchema,
    final JSFunction execute,
  });
}

/// Registers tools on `navigator.modelContext` after [MCPToolkitExtensions.addEntries].
///
/// `web/agentkit_webmcp.generated.js` may register the same names before Flutter
/// loads. Those handlers run JS `validateInput`, then delegate to
/// [globalContext]'s `__agentkitWebMcpDartExecute` when this bootstrap installs
/// it (full [AgentCallEntry.invokeDirect] validation). If no Dart entry exists,
/// execute falls back to `fetch('/agent/invoke')` per ADR 0008.
void registerFromEntries(final Set<AgentCallEntry> entries) {
  final modelContext = _readModelContext();
  if (modelContext == null) {
    return;
  }

  _ensureDartExecuteHook();

  for (final entry in entries) {
    final descriptor = entry.toRegistration().descriptor;
    if (descriptor.kind != AgentIntentKind.tool) {
      continue;
    }

    final qualifiedName = descriptor.qualifiedName;
    _entriesByQualifiedName[qualifiedName] = entry;

    if (_webMcpRegisteredToolNames.contains(qualifiedName)) {
      continue;
    }
    final toolDefinition = _WebMcpToolDefinition(
      name: qualifiedName.toJS,
      description: descriptor.description.toJS,
      inputSchema: _jsonParse(jsonEncode(descriptor.inputSchema).toJS)!,
      execute: ((final JSAny? rawArgs) => _invokeEntry(entry, rawArgs).toJS).toJS,
    );
    try {
      modelContext.registerTool(toolDefinition);
      _webMcpRegisteredToolNames.add(qualifiedName);
    } on Object {
      // Duplicate name (JS bootstrap registered first) — JS execute uses hook.
    }
  }
}

void _ensureDartExecuteHook() {
  if (_dartExecuteHookInstalled) {
    return;
  }
  _dartExecuteHookInstalled = true;
  globalContext.setProperty(
    '__agentkitWebMcpDartExecute'.toJS,
    ((final JSString nameJS, final JSAny? rawArgs) {
      return _dartExecuteHook(nameJS, rawArgs).toJS;
    }).toJS,
  );
}

Future<JSAny?> _dartExecuteHook(
  final JSString nameJS,
  final JSAny? rawArgs,
) async {
  final entry = _entriesByQualifiedName[nameJS.toDart];
  if (entry == null) {
    return null;
  }
  return _invokeEntry(entry, rawArgs);
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
      if (result.details.isNotEmpty) 'details': result.details,
    };
  }
  return <String, Object?>{'ok': true, ...result.data};
}
