/// Documents a tool parameter for schema generation.
class AgentParam {
  const AgentParam({
    required this.description,
    this.required = true,
  });

  final String description;
  final bool required;
}
