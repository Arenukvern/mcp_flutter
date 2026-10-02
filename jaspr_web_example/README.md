# Jaspr web IntentCall example

Web-only IntentCall host profile for Jaspr (or any Dart web server) using the
**three-gate CI recipe**:

1. `dart run build_runner build --delete-conflicting-outputs`
2. `intentcall manifest export --check`
3. `intentcall platform sync --platform web --check`

From the mcp_flutter repo root:

```bash
bash tool/contracts/check_intentcall_jaspr_three_gate.sh
```

Or run the committed hook:

```bash
cd jaspr_web_example
bash .intentcall/web_build_hook.sh
intentcall platform sync --platform web --check
```

`flutter-mcp-toolkit codegen sync` delegates to `intentcall platform sync`
for Flutter apps; Jaspr projects call `intentcall` directly.

Initialize hooks once:

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart init intentcall-platform \
  --project-dir jaspr_web_example
# or: intentcall platform hooks init --host jaspr --project-dir .
```
