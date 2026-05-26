# Publishing agentkit to pub.dev

## Prerequisites

- `dart pub` logged in (`dart pub token add https://pub.dev`)
- All packages at the same semver (currently **0.1.0**)
- `make test` green in this workspace

## Order (required)

1. `agentkit_schema`
2. `agentkit_core`
3. `agentkit_mcp`, `agentkit_webmcp`, `agentkit_gemma`, `agentkit_apple`, `agentkit_android`, `agentkit_codegen`
4. `agentkit_platform` (Flutter plugin — may need `flutter pub publish`)
5. `agentkit_testing`

## Commands

```bash
# Validate all packages (CI uses this)
make publish-dry-run

# After credentials are configured
bash ../tool/agentkit/publish_all.sh --execute
```

For `agentkit_platform`, if `dart pub publish` fails on Flutter constraints, run from package dir:

```bash
cd agentkit/packages/agentkit_platform && flutter pub publish --dry-run
```

## After publish (mcp_flutter cutover)

See `docs/agentkit/hosted_cutover.md` and run:

```bash
bash tool/agentkit/print_hosted_deps.sh
```

Replace `path:` entries in `mcp_toolkit`, `mcp_server_dart`, and capability packages with hosted `^0.1.0`.
