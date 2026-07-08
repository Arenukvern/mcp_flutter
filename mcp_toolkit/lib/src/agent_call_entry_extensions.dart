import 'package:intentcall_core/intentcall_core.dart';

/// MCP toolkit helpers for [AgentCallEntry] service-extension registration.
extension AgentCallEntryMcpToolkit on AgentCallEntry {
  bool get hasTool => value.kind == AgentIntentKind.tool;

  bool get hasResource => value.kind == AgentIntentKind.resource;

  /// Resolves the MCP resource URI for dynamic registration.
  ///
  /// Uses an explicit [AgentIntentDescriptor.resourceUri] when set, otherwise
  /// derives from [protocolScheme] via IntentCall rules, or falls back to the
  /// legacy `visual://localhost/...` shape when no scheme is configured.
  String resolveResourceUri(final String? protocolScheme) {
    final descriptor = toRegistration().descriptor;
    final explicit = descriptor.resourceUri?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final scheme = protocolScheme?.trim() ?? '';
    if (scheme.isNotEmpty) {
      return descriptor.effectiveResourceUri(scheme);
    }
    return 'visual://localhost/${descriptor.name.split('_').join('/')}';
  }

  String get serviceExtensionName =>
      toRegistration().descriptor.effectiveMethodName;
}
