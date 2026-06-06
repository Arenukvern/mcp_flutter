# intentcall hosted dependency cutover (Phase 7.5 / 7.7)

Status: **complete**. `mcp_flutter` consumers now use hosted `intentcall_* ^0.1.0` packages. Keep this page as the regression checklist for future hosted cutovers.

## Checklist

1. Confirm versions on [pub.dev](https://pub.dev) (`intentcall_schema`, `intentcall_core`, …).
2. Run `bash tool/intentcall/print_hosted_deps.sh` for the target version.
3. Update pubspecs:
   - `mcp_toolkit/pubspec.yaml`
   - `mcp_server_dart/pubspec.yaml`
   - `packages/server_capability_kernel/pubspec.yaml`
   - `packages/server_capability_core/pubspec.yaml`
   - `flutter_test_app/pubspec.yaml` (dogfood overrides)
4. Remove root `pubspec.yaml` `dependency_overrides` for `intentcall_*` and consumer `path:` entries.
5. `dart pub get` at repo root and `flutter pub get` in `flutter_test_app`.
6. `make check-intentcall-integration` and `make check-contracts`.

## CI (7.7)

Keep a weekly job or branch rule that fails if path deps to `intentcall/packages`, `agentkit/packages`, or `path: .*intentcall` reappear in consumer pubspecs.

Path dependencies are now local-development-only. Do not restore them for normal hosted integration.
