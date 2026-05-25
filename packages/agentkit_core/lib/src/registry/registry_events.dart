sealed class AgentRegistryEvent {
  const AgentRegistryEvent({required this.timestamp});
  final DateTime timestamp;
}

final class IntentRegistered extends AgentRegistryEvent {
  IntentRegistered({required super.timestamp, required this.qualifiedName});
  final String qualifiedName;
}

final class IntentUnregistered extends AgentRegistryEvent {
  IntentUnregistered({required super.timestamp, required this.qualifiedName});
  final String qualifiedName;
}
