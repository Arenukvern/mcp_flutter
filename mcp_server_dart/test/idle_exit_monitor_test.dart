// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';

import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/idle_exit_monitor.dart';
import 'package:test/test.dart';

void main() {
  // Generous margins so slow CI machines never flake: the assertions check
  // the monitor's decisions, not wall-clock precision.
  group('IdleExitMonitor', () {
    test('exits after the idle timeout when disconnected', () async {
      final exits = <String>[];
      final monitor = IdleExitMonitor(
        idleTimeout: const Duration(milliseconds: 80),
        isVmServiceConnected: () => false,
        onExit: exits.add,
        checkInterval: const Duration(milliseconds: 20),
      )..start();

      await Future<void>.delayed(const Duration(milliseconds: 250));
      monitor.dispose();

      expect(exits, hasLength(1));
      expect(exits.single, contains('Idle exit'));
    });

    test('never exits while the VM service is connected', () async {
      var connected = true;
      final exits = <String>[];
      final monitor = IdleExitMonitor(
        idleTimeout: const Duration(milliseconds: 60),
        isVmServiceConnected: () => connected,
        onExit: exits.add,
        checkInterval: const Duration(milliseconds: 20),
      )..start();

      await Future<void>.delayed(const Duration(milliseconds: 200));
      monitor.dispose();

      expect(exits, isEmpty);
      connected = false; // silence analyzer pref for mutable capture
    });

    test('touch resets the idle window', () async {
      final exits = <String>[];
      final monitor = IdleExitMonitor(
        idleTimeout: const Duration(milliseconds: 120),
        isVmServiceConnected: () => false,
        onExit: exits.add,
        checkInterval: const Duration(milliseconds: 20),
      )..start();

      // Keep stamping activity well past the idle timeout.
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        monitor.touch();
      }
      expect(exits, isEmpty);

      // Stop touching and give the monitor time to cross the threshold.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      monitor.dispose();

      expect(exits, hasLength(1));
    });

    test('zero timeout disables the monitor', () async {
      final exits = <String>[];
      final monitor = IdleExitMonitor(
        idleTimeout: Duration.zero,
        isVmServiceConnected: () => false,
        onExit: exits.add,
        checkInterval: const Duration(milliseconds: 10),
      )..start();

      await Future<void>.delayed(const Duration(milliseconds: 60));
      monitor.dispose();

      expect(exits, isEmpty);
    });

    test('dispose cancels a pending exit', () async {
      final exits = <String>[];
      final monitor = IdleExitMonitor(
        idleTimeout: const Duration(milliseconds: 80),
        isVmServiceConnected: () => false,
        onExit: exits.add,
        checkInterval: const Duration(milliseconds: 20),
      )..start();

      await Future<void>.delayed(const Duration(milliseconds: 30));
      monitor.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(exits, isEmpty);
    });
  });
}
