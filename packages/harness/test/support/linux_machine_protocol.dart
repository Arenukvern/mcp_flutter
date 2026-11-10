/// Flutter `run --machine` line parsing (mirrors flutter_tools `parseFlutterResponse`).
library;

import 'dart:convert';

/// First JSON object on a machine line (`[{...}]`), or null.
Map<String, Object?>? unwrapFlutterMachineLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return null;
  if (!trimmed.startsWith('[') || !trimmed.endsWith(']') || trimmed.length <= 2) {
    return null;
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      return Map<String, Object?>.from(decoded.first as Map);
    }
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
  } on Object {
    return null;
  }
  return null;
}

/// `true` ack, `false` explicit error, `null` not a stop ack for [stopRequestId].
bool? machineAppStopAckFromPayload(
  Map<String, Object?> payload, {
  required int stopRequestId,
  String? expectedAppId,
}) {
  final id = payload['id'];
  if (id is int && id == stopRequestId) {
    if (payload.containsKey('error')) return false;
    if (payload.containsKey('result')) return true;
  }
  if (payload['event'] == 'app.stop') {
    final params = payload['params'];
    if (params is Map) {
      final appId = params['appId'];
      if (expectedAppId != null &&
          appId is String &&
          appId.isNotEmpty &&
          appId != expectedAppId) {
        return null;
      }
      if (params.containsKey('error')) return false;
    }
    return true;
  }
  return null;
}

bool? machineAppStopAckFromLine(
  String line, {
  required int stopRequestId,
  String? expectedAppId,
}) {
  final payload = unwrapFlutterMachineLine(line);
  if (payload == null) return null;
  return machineAppStopAckFromPayload(
    payload,
    stopRequestId: stopRequestId,
    expectedAppId: expectedAppId,
  );
}
