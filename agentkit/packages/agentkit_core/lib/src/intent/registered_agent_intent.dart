import 'package:agentkit_schema/agentkit_schema.dart';

import 'agent_intent_descriptor.dart';
import 'agent_invocation.dart';

typedef AgentExecutor = Future<AgentResult> Function(AgentInvocation invocation);
typedef AgentValidator = void Function(AgentArguments arguments);

final class RegisteredAgentIntent {
  RegisteredAgentIntent({
    required this.descriptor,
    required final AgentExecutor execute,
    final AgentValidator? validate,
  }) : _execute = execute,
       _validate =
           validate ??
           ((final args) {
             final coerced = coerceArgumentsForSchema(
               descriptor.inputSchema,
               args,
             );
             validateAgainstSchema(descriptor.inputSchema, coerced);
           });

  final AgentIntentDescriptor descriptor;
  final AgentExecutor _execute;
  final AgentValidator _validate;

  String get qualifiedName => descriptor.qualifiedName;

  void validate(final AgentArguments arguments) => _validate(arguments);

  Future<AgentResult> execute(final AgentInvocation invocation) =>
      _execute(invocation);
}
