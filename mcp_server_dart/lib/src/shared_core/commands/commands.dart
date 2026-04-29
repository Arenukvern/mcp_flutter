// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: combinators_ordering

// CoreCommand sealed hierarchy re-exported from mcp_shared_core.
// CommandCatalog and CommandSpec remain server-only (they build input schemas
// and dispatch logic, not pure value types).
export 'package:mcp_shared_core/mcp_shared_core.dart'
    show
        // Core sealed class + factory typedef
        CoreCommand,
        CoreCommandFactory,
        CoreConnectionMode,
        // Connection commands
        ConnectCommand,
        SessionStartCommand,
        SessionEndCommand,
        SessionExecCommand,
        // Basic VM commands
        StatusCommand,
        GetVmCommand,
        GetExtensionRpcsCommand,
        GetActivePortsCommand,
        GetAppErrorsCommand,
        HotReloadFlutterCommand,
        HotRestartFlutterCommand,
        WatchCommand,
        ExplainErrorsCommand,
        // Visual / widget commands
        ScreenshotMode,
        parseScreenshotMode,
        GetViewDetailsCommand,
        GetScreenshotsCommand,
        InspectWidgetAtPointCommand,
        CaptureUiSnapshotCommand,
        SemanticSnapshotCommand,
        TapWidgetCommand,
        EnterTextCommand,
        ScrollCommand,
        LongPressCommand,
        SwipeCommand,
        DragCommand,
        HotReloadAndCaptureCommand,
        EvaluateDartExpressionCommand,
        GetRecentLogsCommand,
        WaitForCommand,
        PressKeyCommand,
        HandleDialogCommand,
        NavigateCommand,
        FillFormCommand,
        HoverCommand,
        // Debug commands
        DebugDumpFocusTreeCommand,
        DebugDumpLayerTreeCommand,
        DebugDumpRenderTreeCommand,
        DebugDumpSemanticsTreeCommand,
        DiagnoseCommand,
        DiscoverDebugAppsCommand,
        DynamicRegistryStatsCommand,
        // Dynamic registry commands
        ListClientToolsAndResourcesCommand,
        RunClientResourceCommand,
        RunClientToolCommand;

// Server-only: CommandCatalog and CommandSpec — live here because they
// depend on transport-coupled helpers (schema builders, arg parsers) and
// import visual_capture.dart for PermissionPolicy schema population.
export 'commands_catalog.dart';
