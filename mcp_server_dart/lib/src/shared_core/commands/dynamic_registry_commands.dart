part of 'commands.dart';

final class RunClientResourceCommand extends CoreCommand {
  const RunClientResourceCommand({required this.resourceUri});

  final String resourceUri;

  @override
  String get name => 'runClientResource';
}

final class RunClientToolCommand extends CoreCommand {
  const RunClientToolCommand({
    required this.toolName,
    this.arguments = const <String, Object?>{},
  });

  final String toolName;
  final Map<String, Object?> arguments;

  @override
  String get name => 'runClientTool';
}
