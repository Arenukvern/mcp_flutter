/// Marks a method or class as an agent tool for optional codegen.
class AgentTool {
  const AgentTool({
    this.name,
    this.description = '',
    this.namespace = 'app',
  });

  final String? name;
  final String description;
  final String namespace;
}
