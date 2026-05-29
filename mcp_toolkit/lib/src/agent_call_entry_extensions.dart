import 'package:intentcall_core/intentcall_core.dart';

/// MCP toolkit helpers for [AgentCallEntry] service-extension registration.
extension AgentCallEntryMcpToolkit on AgentCallEntry {
  bool get hasTool => value.kind == AgentIntentKind.tool;

  bool get hasResource => value.kind == AgentIntentKind.resource;

  String get resourceUri => toRegistration().descriptor.effectiveResourceUri;

  String get serviceExtensionName =>
      toRegistration().descriptor.effectiveMethodName;
}
