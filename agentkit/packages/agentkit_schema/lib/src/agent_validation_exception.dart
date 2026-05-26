final class AgentValidationException implements Exception {
  AgentValidationException(this.message);
  final String message;

  @override
  String toString() => 'AgentValidationException: $message';
}
