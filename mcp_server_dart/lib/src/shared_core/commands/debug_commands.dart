part of 'commands.dart';

final class DebugDumpFocusTreeCommand extends CoreCommand {
  const DebugDumpFocusTreeCommand();

  @override
  String get name => 'debug_dump_focus_tree';
}

final class DebugDumpLayerTreeCommand extends CoreCommand {
  const DebugDumpLayerTreeCommand();

  @override
  String get name => 'debug_dump_layer_tree';
}

final class DebugDumpRenderTreeCommand extends CoreCommand {
  const DebugDumpRenderTreeCommand();

  @override
  String get name => 'debug_dump_render_tree';
}

final class DebugDumpSemanticsTreeCommand extends CoreCommand {
  const DebugDumpSemanticsTreeCommand();

  @override
  String get name => 'debug_dump_semantics_tree';
}

final class DiagnoseCommand extends CoreCommand {
  const DiagnoseCommand({this.includeViewDetails = false});

  final bool includeViewDetails;

  @override
  String get name => 'diagnose';
}

final class DiscoverDebugAppsCommand extends CoreCommand {
  const DiscoverDebugAppsCommand();

  @override
  String get name => 'discover_debug_apps';
}

final class DynamicRegistryStatsCommand extends CoreCommand {
  const DynamicRegistryStatsCommand({this.includeAppDetails = true});

  final bool includeAppDetails;

  @override
  String get name => 'dynamicRegistryStats';
}
