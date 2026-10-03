/// Programmatic E2E harness for Flutter apps (ADR-0015).
///
/// A harness must own the whole lifecycle — build the app, launch the
/// process, attach to its VM service, and only then drive/assert. Anything
/// that shells out for the build or discovers the VM by scraping files
/// becomes a pile of shell.
///
/// Composition: a [Scenario] is a list of named [Step]s run against a
/// [HarnessContext]; each step either passes, retries, or fails.
/// `example/` shows a full two-instance composition root.
///
/// The driving layer speaks the `ext.mcp.toolkit.*` service extensions that
/// [mcp_toolkit](https://pub.dev/packages/mcp_toolkit) registers in the app;
/// see [ToolkitExtensions] for the name list and its source of truth.
library;

export 'package:universal_automation_interface/universal_automation_interface.dart';

export 'src/check.dart';
export 'src/chrome_app_target.dart';
export 'src/driver_session.dart';
export 'src/flutter_app.dart';
export 'src/flutter_run.dart';
export 'src/intent_driver_router.dart';
export 'src/log_tap.dart';
export 'src/scenario.dart';
export 'src/toolkit_driver.dart';
export 'src/toolkit_extensions.dart';
export 'src/vm_client.dart';
export 'src/vm_service_uri.dart';
