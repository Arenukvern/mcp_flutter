// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.
//
// Verifies the single-flight gate inside [ConnectionContext] for hot reload
// and hot restart. The real VM-service path is exercised in integration tests;
// here we rely on the early-return "VM service not connected" branch, which
// still flows through the gate and lets us observe that two overlapping
// callers share the same [Future] rather than each issuing an independent
// reload.

import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

ConnectionContext _makeContext() => ConnectionContext(
  defaultHost: 'localhost',
  defaultPort: 8181,
  logger: (final level, final message, {final logger = 'test'}) {},
  discoverPorts: () async => <int>[],
);

void main() {
  group('hot reload single-flight', () {
    test('two concurrent hotReload calls share the same Future', () async {
      final context = _makeContext();

      final firstCall = context.hotReload();
      final secondCall = context.hotReload();

      // Identity check — the gate should hand back the in-flight future,
      // not issue a second reload.
      expect(identical(firstCall, secondCall), isTrue);

      final firstResult = await firstCall;
      final secondResult = await secondCall;
      expect(firstResult, equals(secondResult));
    });

    test('hotRestart reuses the in-flight hotReload future', () async {
      final context = _makeContext();

      final reload = context.hotReload();
      final restart = context.hotRestart();

      // Both operations share one gate; the second caller waits.
      expect(identical(reload, restart), isTrue);

      await reload;
      await restart;
    });

    test('gate clears after completion so a later call re-enters', () async {
      final context = _makeContext();

      final first = context.hotReload();
      await first;

      final second = context.hotReload();
      expect(identical(first, second), isFalse);
      await second;
    });
  });
}
