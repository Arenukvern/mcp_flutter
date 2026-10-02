import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:test/test.dart';

/// Opt-in smoke test against real Chrome: `XS_TEST_CHROME=1 dart test`.
/// Ownership rules are exercised without Chrome via [ChromeAppTarget]'s
/// borrowed-session path only when a real browser is present, so this
/// stays out of the default gate (the oka real-Chrome smoke pattern).
void main() {
  test(
    'launches Chrome, attaches a driver, and stops what it owns',
    () async {
      if (Platform.environment['XS_TEST_CHROME'] != '1') {
        return;
      }
      final target = ChromeAppTarget(
        port: 19222,
        startUrl: Uri.parse('data:text/html,<title>smoke</title>'),
      );
      final chrome = await target.launch();
      expect(chrome.borrowed, isFalse);
      final driver = await chrome.driver();
      expect(driver.capabilities.a11yTree, isTrue);
      final snapshot = await driver.snapshot();
      expect(snapshot.roots, isNotEmpty);
      final code = await chrome.stop();
      expect(code, isNot(equals(-1)));
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('refuses a build step it does not own', () {
    expect(
      () => ChromeAppTarget(port: 19222).launch(build: true),
      throwsArgumentError,
    );
  });
}
