import 'package:flutter/widgets.dart';
import 'package:flutter_live_edit_agent/flutter_live_edit_agent.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:test_app/live_edit/app_live_edit_config.dart';
import 'package:test_app/live_edit/app_live_edit_delegate.dart';

@visibleForTesting
LiveEditOrchestrator? debugLiveEditOrchestratorOverride;

final LiveEditAgentService _liveEditAgentService = LiveEditAgentService();
final List<LiveEditAgentBackend> _liveEditBackends = _liveEditAgentService
    .listBackends();

class TestAppLiveEditHost extends StatelessWidget {
  const TestAppLiveEditHost({required this.child, super.key, this.config});

  final Widget child;
  final TestAppLiveEditConfig? config;

  @override
  Widget build(final BuildContext context) {
    final resolvedConfig = config ?? TestAppLiveEditConfig.fromEnvironment();
    final orchestrator = debugLiveEditOrchestratorOverride;
    final delegateFactory = TestAppLiveEditDelegateFactory(
      config: resolvedConfig,
      agentService: _liveEditAgentService,
      availableBackends: _liveEditBackends,
    );
    return FlutterLiveEditHost(
      orchestrator: orchestrator,
      applyDraftDelegate: orchestrator == null ? delegateFactory.apply : null,
      backendId: orchestrator == null ? resolvedConfig.backendId : null,
      availableBackends: orchestrator == null
          ? _liveEditBackends
          : const <LiveEditAgentBackend>[],
      workingDirectory: orchestrator == null
          ? resolvedConfig.hostWorkingDirectory
          : null,
      intentText: orchestrator == null ? resolvedConfig.hostIntentText : null,
      child: child,
    );
  }
}
