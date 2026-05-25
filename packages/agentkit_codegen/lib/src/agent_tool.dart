/// Marks a top-level function as an agent tool for optional codegen.
class AgentTool {
  const AgentTool({
    required this.name,
    this.description = '',
    this.namespace = 'app',
  });

  final String name;
  final String description;
  final String namespace;
}
