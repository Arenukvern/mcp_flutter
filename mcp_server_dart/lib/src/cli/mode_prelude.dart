import 'package:flutter_mcp_toolkit_server/src/cli/init_mode.dart';

const _placeholder = '<!-- @FMT_MODE_PRELUDE -->';

const _mcpPrelude = '''
> Calls in this skill are MCP tools registered by `flutter-mcp-toolkit-server`.
> Tool names match the bare name in this skill (e.g. `tap_widget` → `fmt_tap_widget`).
> Errors return the standard envelope: read `error.code` and follow `error.recovery`.
> If the tool isn't in your tool list, the MCP server isn't connected — see `flutter-mcp-toolkit-setup`.''';

const _cliPrelude = '''
> Calls in this skill run via the `flutter-mcp-toolkit` CLI binary:
>     flutter-mcp-toolkit exec --name <tool> --args '<json>'
> Output is JSON on stdout. Errors come as `{"error":{"code":..., "message":..., "recovery":...}}`.
> Throughout this skill, calls are written as `tap_widget(selector: "...")` — translate to the CLI form.
> If the binary isn't on PATH, see `flutter-mcp-toolkit-setup`.''';

String renderModePrelude(final String body, final InitMode mode) {
  if (mode == InitMode.auto) {
    throw ArgumentError.value(
      mode,
      'mode',
      'auto must be resolved to mcp or cli before rendering',
    );
  }
  if (!body.contains(_placeholder)) {
    throw StateError('Skill body missing $_placeholder');
  }
  final prelude = mode == InitMode.mcp ? _mcpPrelude : _cliPrelude;
  return body.replaceFirst(_placeholder, prelude);
}
