// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';

/// Exits the server after [idleTimeout] without an incoming MCP message and
/// without a VM service connection.
///
/// MCP clients keep stdio servers alive as long as a conversation stays open
/// (resumable for days), so EOF-based cleanup never fires for idle
/// conversations and one server process accumulates per conversation ×
/// project. The monitor makes the idle case exit explicitly instead.
///
/// A connected VM service counts as activity: a live debug session with a
/// quiet client is not idle, so the idle window effectively starts at
/// disconnect.
final class IdleExitMonitor {
  IdleExitMonitor({
    required this._idleTimeout,
    required this._isVmServiceConnected,
    required this._onExit,
    this._checkInterval = const Duration(minutes: 1),
  }) {
    touch();
  }

  final Duration _idleTimeout;
  final bool Function() _isVmServiceConnected;
  final void Function(String reason) _onExit;
  final Duration _checkInterval;

  DateTime _lastActivity = DateTime.now();
  Timer? _timer;
  bool _stopped = false;

  /// Stamp activity: every incoming MCP message resets the idle window.
  void touch() {
    _lastActivity = DateTime.now();
  }

  /// Starts the periodic idle check. No-op when [idleTimeout] is zero or
  /// negative (the disabled case).
  void start() {
    if (_stopped || _idleTimeout <= Duration.zero) {
      return;
    }
    _timer = Timer.periodic(_checkInterval, (_) => _check());
  }

  void _check() {
    if (_stopped) {
      return;
    }
    if (_isVmServiceConnected()) {
      // A live app session is never idle, even with a quiet client.
      touch();
      return;
    }
    final idleFor = DateTime.now().difference(_lastActivity);
    if (idleFor < _idleTimeout) {
      return;
    }
    stop();
    _onExit(
      'Idle exit: no MCP requests and no VM service connection for '
      '${idleFor.inMinutes} minute(s) (threshold: '
      '${_idleTimeout.inMinutes}). Restart happens automatically when the '
      'client next uses a tool.',
    );
  }

  /// Cancels the periodic check without invoking [onExit].
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _stopped = true;
  }

  void stop() {
    dispose();
  }
}
