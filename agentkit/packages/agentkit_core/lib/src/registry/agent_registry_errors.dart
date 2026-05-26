final class AgentIntentCollisionError implements Exception {
  AgentIntentCollisionError(this.message);
  final String message;

  @override
  String toString() => 'AgentIntentCollisionError: $message';
}

final class AgentIntentNotFoundError implements Exception {
  AgentIntentNotFoundError(this.qualifiedName);
  final String qualifiedName;

  @override
  String toString() => 'AgentIntentNotFoundError: $qualifiedName';
}
