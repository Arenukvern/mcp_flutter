@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_cdp_discovery.dart';
import 'package:test/test.dart';

/// Opt-in: `RUN_WEB_CDP_INTEGRATION=1 dart test test/web_cdp_integration_test.dart`
///
/// Requires a running `flutter run -d chrome` with Chrome remote debugging active.
void main() {
  test(
    'discovers live Chrome CDP endpoint when integration env is set',
    () async {
      if (Platform.environment['RUN_WEB_CDP_INTEGRATION'] != '1') {
        return;
      }
      final override = int.tryParse(
        Platform.environment['WEB_BROWSER_DEBUGGING_PORT'] ?? '',
      );
      final endpoint = await discoverWebCdpEndpoint(
        configuration: CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: true,
          saveImagesToFiles: false,
          webBrowserDebuggingPort: override,
        ),
      );
      expect(endpoint, isNotNull, reason: 'Start flutter run -d chrome first');
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}
