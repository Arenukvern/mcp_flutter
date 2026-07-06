#!/usr/bin/env bash
# intentcall-platform: begin
set -euo pipefail
dart run build_runner build --delete-conflicting-outputs
intentcall manifest export --check
intentcall platform sync --platform web || exit 1
# intentcall-platform: end
