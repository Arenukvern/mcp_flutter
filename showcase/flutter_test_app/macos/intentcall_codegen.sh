# intentcall-platform: begin
cd "${SRCROOT}/.."
dart run build_runner build --delete-conflicting-outputs
dart run intentcall_cli:intentcall manifest export --check
dart run intentcall_cli:intentcall platform sync --platform ios,macos || exit 1
# intentcall-platform: end
