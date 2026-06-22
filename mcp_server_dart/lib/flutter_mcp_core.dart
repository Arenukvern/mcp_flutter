// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

/// Broad compatibility barrel for server-side Flutter MCP internals.
///
/// New consumers should prefer focused public surfaces such as
/// `flutter_mcp_attach.dart`, `intentcall_session`, and package-specific
/// capability APIs. This barrel remains for existing server/CLI integrations.
library;

export 'src/capabilities/ai_providers/error_summary_provider.dart';
export 'src/capabilities/core/capabilities_model.dart';
export 'src/capabilities/diagnostics/diagnostics_bundle.dart';
export 'src/capabilities/dynamic_registry/dynamic_gateway.dart';
export 'src/capabilities/error_analysis/error_analysis.dart';
export 'src/capabilities/visual_capture/core_image_file_saver.dart';
export 'src/capabilities/visual_capture/visual_capture.dart';
export 'src/cli/cli_daemon_server.dart';
export 'src/cli/diagnostics/bundle_builder.dart';
export 'src/cli/diagnostics/command_snapshot_service.dart';
export 'src/cli/diagnostics/doctor_runner.dart';
export 'src/runtime_version.dart';
export 'src/shared_core/shared_core.dart';
