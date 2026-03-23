import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

import '../../ai/agent/live_edit_agent_service.dart';
import '../../di_live_edit_context/live_edit_orchestrator.dart';
import '../../di_live_edit_context/live_edit_scope.dart';
import '../../mcp_toolkit_tools/live_edit_toolkit.dart';
import '../../models/models.dart';
import '../../types/live_edit_types.dart';
import '../core/live_edit_host.dart';
import 'flutter_live_edit_auto_host_config.dart';
import 'flutter_live_edit_auto_host_delegate.dart';

/// fast way to bootstrap the live edit app.
/// useful for demos and testing.
Future<void> bootstrapFlutterLiveEditApp({
  required final void Function() runApp,
  final Future<void> Function()? initializeApp,
  final Future<void> Function()? registerInitialEntries,
  final Future<void> Function()? registerDelayedEntries,
  final Duration delayedRegistrationDelay = const Duration(seconds: 5),
  final FlutterLiveEditAutoConfig? config,
  final void Function(Object error, StackTrace stackTrace)? onError,
}) async {
  final resolvedConfig = config ?? FlutterLiveEditAutoConfig.fromEnvironment();
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (kIsWeb && resolvedConfig.enableWebSemantics) {
        SemanticsBinding.instance.ensureSemantics();
      }
      MCPToolkitBinding.instance
        ..initialize()
        ..initializeFlutterToolkit();
      await MCPToolkitBinding.instance.initializeFlutterLiveEditToolkit();

      if (initializeApp != null) {
        await initializeApp();
      }
      if (registerInitialEntries != null) {
        await registerInitialEntries();
      }
      runApp();

      if (registerDelayedEntries != null) {
        Timer(
          delayedRegistrationDelay,
          () => unawaited(registerDelayedEntries()),
        );
      }
    },
    (final error, final stackTrace) {
      if (onError != null) {
        onError(error, stackTrace);
        return;
      }
      MCPToolkitBinding.instance.handleZoneError(error, stackTrace);
    },
  );
}

@visibleForTesting
LiveEditOrchestrator? debugFlutterLiveEditAutoHostOrchestratorOverride;

class FlutterLiveEditAutoHost extends StatelessWidget {
  FlutterLiveEditAutoHost({
    required this.child,
    super.key,
    this.config,
    this.orchestrator,
    this.applyDraftDelegate,
    final LiveEditAgentService? agentService,
  }) : _agentService = agentService ?? LiveEditAgentService();

  final Widget child;
  final FlutterLiveEditAutoConfig? config;
  final LiveEditOrchestrator? orchestrator;
  final LiveEditApplyDraftDelegate? applyDraftDelegate;
  final LiveEditAgentService _agentService;

  @override
  Widget build(final BuildContext context) {
    final resolvedConfig =
        config ?? FlutterLiveEditAutoConfig.fromEnvironment();
    final resolvedOrchestrator =
        orchestrator ?? debugFlutterLiveEditAutoHostOrchestratorOverride;
    final backends =
        resolvedConfig.availableBackends ?? _agentService.listBackends();
    final defaultDelegate =
        applyDraftDelegate ??
        FlutterLiveEditAutoDelegate(
          config: resolvedConfig,
          agentService: _agentService,
          availableBackends: backends,
        ).apply;
    final host = FlutterLiveEditHost(
      orchestrator: resolvedOrchestrator,
      applyDraftDelegate: resolvedOrchestrator == null ? defaultDelegate : null,
      backendId: resolvedOrchestrator == null ? resolvedConfig.backendId : null,
      availableBackends: resolvedOrchestrator == null
          ? backends
          : const <LiveEditAgentBackend>[],
      workingDirectory: resolvedOrchestrator == null
          ? resolvedConfig.hostWorkingDirectory
          : null,
      intentText: resolvedOrchestrator == null
          ? resolvedConfig.hostIntentText
          : null,
      child: child,
    );
    if (resolvedOrchestrator == null) {
      return LiveEditScope(
        applyDraftDelegate: defaultDelegate,
        backendId: resolvedConfig.backendId,
        availableBackends: backends,
        workingDirectory: resolvedConfig.hostWorkingDirectory,
        intentText: resolvedConfig.hostIntentText,
        child: host,
      );
    }
    return host;
  }
}
