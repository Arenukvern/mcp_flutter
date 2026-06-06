// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

/// Public attach/execution primitives for harness-style consumers.
///
/// Keep this surface intentionally small. Broader MCP server internals remain
/// available only through package-private `src/` imports.
library;

export 'src/capabilities/visual_capture/core_image_file_saver.dart'
    show CoreImageFileSaver;
export 'src/shared_core/command_executor.dart'
    show CoreCommandExecutor, DefaultCoreCommandExecutor;
export 'src/shared_core/vm_connections/connection_context.dart'
    show
        ConnectionContext,
        CoreConnectionException,
        CoreConnectionFailureReason,
        CoreConnectionTarget,
        EnsureConnectionResult;
export 'src/shared_core/vm_connections/core_port_scanner.dart'
    show CorePortScanner;
export 'src/shared_core/vm_connections/flutter_tool_machine_discovery.dart'
    show FlutterMachineDiscoveryTarget, FlutterToolMachineDiscovery;
