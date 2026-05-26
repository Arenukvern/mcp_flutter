import 'package:agentkit_core/agentkit_core.dart';

/// No-op on non-web targets.
Future<void> wireWebMcpPublishAdapterDogfood(
  final Set<AgentCallEntry> entries,
) async {}
