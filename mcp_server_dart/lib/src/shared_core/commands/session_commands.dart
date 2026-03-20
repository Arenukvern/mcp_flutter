part of 'commands.dart';

final class SessionEndCommand extends CoreCommand {
  const SessionEndCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => 'session_end';
}

final class SessionExecCommand extends CoreCommand {
  const SessionExecCommand({required this.command, this.sessionId});

  final String? sessionId;
  final CoreCommand command;

  @override
  String get name => 'session_exec';
}

final class SessionStartCommand extends CoreCommand {
  const SessionStartCommand({
    this.mode = CoreConnectionMode.auto,
    this.targetId,
    this.uri,
    this.host,
    this.port,
    this.forceReconnect = false,
    this.sessionId,
  });

  final CoreConnectionMode mode;
  final String? targetId;
  final String? uri;
  final String? host;
  final int? port;
  final bool forceReconnect;
  final String? sessionId;

  @override
  String get name => 'session_start';
}
