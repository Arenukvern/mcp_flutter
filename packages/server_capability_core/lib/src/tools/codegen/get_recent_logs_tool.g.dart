// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint

part of 'get_recent_logs_tool.dart';

// **************************************************************************
// AgentToolGenerator
// **************************************************************************

RegisteredAgentIntent get getRecentLogsRegistration =>
    getRecentLogsCallEntry.toRegistration();

AgentCallEntry get getRecentLogsCallEntry => AgentCallEntry.tool(
  namespace: 'fmt',
  name: 'get_recent_logs',
  description:
      'Get recent print() and log output from the running Flutter app.',
  inputSchema: getRecentLogsInputSchema(),
  handler: (final args) async => fmtGetRecentLogs(args['count'] as int),
);
