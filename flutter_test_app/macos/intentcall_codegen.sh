# intentcall-platform: begin
cd "${SRCROOT}/.."
dart run build_runner build --delete-conflicting-outputs
intentcall manifest export --check
intentcall platform sync --platform ios,macos || exit 1
# intentcall-platform: end
