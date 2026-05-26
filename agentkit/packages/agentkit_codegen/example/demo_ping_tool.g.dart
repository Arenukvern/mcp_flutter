// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint

part of 'demo_ping_tool.dart';

// **************************************************************************
// AgentToolGenerator
// **************************************************************************

const _demo_pingInputSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'message': <String, Object?>{
      'type': 'string',
      'description': 'Message to echo',
    },
  },
  'required': <String>['message'],
};

RegisteredAgentIntent get demoPingRegistration =>
    demoPingCallEntry.toRegistration();

AgentCallEntry get demoPingCallEntry => AgentCallEntry.tool(
  namespace: 'app',
  name: 'demo_ping',
  description: 'Returns pong for a message',
  inputSchema: _demo_pingInputSchema,
  handler: (final args) async => demoPing(args['message'] as String),
);
