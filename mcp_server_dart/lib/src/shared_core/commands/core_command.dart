part of 'commands.dart';

typedef CoreCommandFactory = CoreCommand Function(Map<String, Object?> args);

/// Canonical command surface shared by CLI and MCP wrapper.
sealed class CoreCommand {
  const CoreCommand();

  String get name;
}

/// Connection mode used by the shared core runtime.
enum CoreConnectionMode { auto, manual, uri }
