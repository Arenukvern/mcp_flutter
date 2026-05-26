// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint

part of 'get_recent_logs_tool.dart';

// **************************************************************************
// AgentToolGenerator
// **************************************************************************

const _get_recent_logsInputSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'count': <String, Object?>{
      'type': 'integer',
      'description': 'Number of recent log entries (default: 50).',
    },
  },
  'required': <String>[],
};

RegisteredAgentIntent get getRecentLogsRegistration =>
    getRecentLogsCallEntry.toRegistration();

AgentCallEntry get getRecentLogsCallEntry => AgentCallEntry.tool(
  namespace: 'fmt',
  name: 'get_recent_logs',
  description:
      'Get recent print() and log output from the running Flutter app.',
  inputSchema: _get_recent_logsInputSchema,
  handler: (final args) async => fmtGetRecentLogs(args['count'] as int),
);
