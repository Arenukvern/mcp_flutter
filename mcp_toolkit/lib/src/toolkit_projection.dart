import 'package:intentcall_core/intentcall_core.dart';

/// A composable platform surface that reacts to the toolkit's entry set.
///
/// Projections are how platform tiers attach to the toolkit — the browser
/// WebMCP registry, native AppIntents/Shortcuts, future session or
/// screencast surfaces. The app adds only the projection packages it wants
/// and registers them in its composition root; the toolkit core depends on
/// no projection (see ADR-0016).
///
/// Full-set semantics: [entriesChanged] receives the toolkit's complete
/// current entry set after every mutation — the same model the VM-service
/// extension registration uses — so implementations can upsert or
/// re-register idempotently.
///
/// ```dart
/// // app composition root (main.dart) — oka-style, explicit, no flags
/// MCPToolkitBinding.instance
///   ..addProjection(WebMcpProjection(policy: myPolicy))
///   ..addProjection(AppIntentsProjection(policy: myPolicy));
/// ```
// Single-method by design: the SPI stays minimal so tiers can attach with
// one entry point. Widen only with strong evidence (see ADR-0016).
// ignore: one_member_abstracts
abstract interface class ToolkitProjection {
  /// Called with the toolkit's full current entry set after entries are
  /// added, replaced, or re-registered.
  void entriesChanged(final Set<AgentCallEntry> entries);
}

/// Adapter for duck-typed projections from other packages (e.g. intentcall's
/// `WebMcpProjection`, which exposes the same `entriesChanged` shape without
/// importing the toolkit). Prefer [MCPToolkitBindingBase.addEntryListener],
/// which wraps a bare listener in this adapter for you.
final class EntryListenerProjection implements ToolkitProjection {
  EntryListenerProjection(this._listener);

  final void Function(Set<AgentCallEntry> entries) _listener;

  @override
  void entriesChanged(final Set<AgentCallEntry> entries) => _listener(entries);
}
