# intentcall hosted dependency cutover (Phase 7.5 / 7.7)

After packages are on pub.dev, switch mcp_flutter consumers from path deps to hosted versions.

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

When cutover is complete, add a weekly job or branch rule that fails if path deps to `intentcall/packages` reappear in consumer pubspecs (optional `tool/intentcall/check_no_path_deps.sh`).

Until publish, **keep path deps** — integration tests depend on the local `intentcall/` workspace.
