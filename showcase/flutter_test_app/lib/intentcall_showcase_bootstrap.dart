import 'package:flutter/foundation.dart';
import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:intentcall_platform/intentcall_platform_flutter.dart';
import 'package:intentcall_platform_sync/intentcall_platform_sync.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:test_app/intentcall_showcase_entries.dart';

final intentCallProofRegistry = InMemoryAgentRegistry();
late final IntentCallFlutterHost intentCallHost;

/// Projects the toolkit's dynamic entries (built-in toolkits + app-registered
/// tools) onto the browser WebMCP registry — the composition-root unit that
/// replaces the toolkit's old hard-wired kIsWeb registration (ADR-0016).
final class ShowcaseWebMcpProjection implements ToolkitProjection {
  const ShowcaseWebMcpProjection({required this.policy});

  final IntentCallAuthorizationPolicy policy;

  @override
  void entriesChanged(final Set<AgentCallEntry> entries) {
    if (!kIsWeb) return;
    projectEntriesToWebMcp(entries, policy: policy);
  }
}

Set<AgentCallEntry> buildIntentCallProofEntries() => {
  buildIntentCallBridgePingEntry(),
  buildSetGreetingEntry(),
  buildEnableSwitchEntry(),
};

Future<void> configureIntentCallShowcase({
  required final Set<AgentCallEntry> proofEntries,
}) async {
  // Toolkit tier: project the toolkit's dynamic entries onto WebMCP with an
  // explicit policy (previously implicit debugAllowAll inside the toolkit).
  MCPToolkitBinding.instance.addProjection(
    ShowcaseWebMcpProjection(
      policy: const IntentCallAuthorizationPolicy.debugAllowAll(),
    ),
  );

  for (final entry in proofEntries) {
    intentCallProofRegistry.register(entry.toRegistration());
  }
  intentCallProofRegistry.registerEntityType(buildShowcaseScreenEntityType());
  intentCallHost = IntentCallFlutterHost.bindRegistry(
    registry: intentCallProofRegistry,
    policy: const IntentCallAuthorizationPolicy(
      allowedSources: <String>{
        IntentCallInvocationSource.webMcpDart,
        IntentCallInvocationSource.nativeGenerated,
        IntentCallInvocationSource.deepLink,
        IntentCallInvocationSource.appleAwaitApp,
        IntentCallInvocationSource.windowsAppAction,
        IntentCallInvocationSource.websocket,
      },
      allowedQualifiedNames: <String>{
        'app_intentcall_bridge_ping',
        'app_set_greeting',
        'app_enable_switch',
      },
    ),
    registerWebMcp: kIsWeb,
    listenForDeepLinks: !kIsWeb,
    protocolScheme: intentCallProtocolScheme,
    publishSurfaceLink: !kIsWeb,
    onEnvelope: (final envelope) {
      debugPrint('intentcall invoke: ${envelope.qualifiedName}');
    },
    onResult: (final envelope, final result) {
      if (envelope.source == IntentCallInvocationSource.nativeGenerated) {
        debugPrint(
          'intentcall pending invocation ${envelope.qualifiedName}: ${result.ok}',
        );
      } else {
        debugPrint(
          'intentcall ${envelope.source} invocation ${envelope.qualifiedName}: ${result.ok}',
        );
      }
    },
    onDenied: (final envelope, final result) {
      debugPrint(
        'intentcall denied ${envelope.source} invocation ${envelope.qualifiedName}: ${result.code}',
      );
    },
    onError: (final envelope, final error, final stackTrace) {
      debugPrint(
        'intentcall error ${envelope.source} invocation ${envelope.qualifiedName}: $error',
      );
    },
  );

  if (kIsWeb) return;
  try {
    await seedIntentCallShowcaseEntities();
  } catch (error, stackTrace) {
    debugPrint('intentcall entity snapshot seed failed: $error');
    debugPrint('$stackTrace');
  }
}
