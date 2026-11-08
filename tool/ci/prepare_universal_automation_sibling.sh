#!/usr/bin/env bash
# Resolves universal_automation 0.4.x workspace packages for CI/local when
# pub.dev has not yet published universal_automation_interface 0.4.0.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
dest="${repo_root}/universal_automation"
overrides="${repo_root}/pubspec_overrides.yaml"

if [[ ! -d "${dest}/pkgs/universal_automation_interface" ]]; then
  echo "prepare_universal_automation_sibling: cloning Arenukvern/universal_automation_ai_device_use"
  rm -rf "${dest}"
  git clone --depth 1 https://github.com/Arenukvern/universal_automation_ai_device_use.git "${dest}"
fi

cat >"${overrides}" <<EOF
dependency_overrides:
  universal_automation_interface:
    path: universal_automation/pkgs/universal_automation_interface
  universal_automation_semantics:
    path: universal_automation/pkgs/universal_automation_semantics
EOF

demo_overrides="${repo_root}/showcase/flutter_demo/pubspec_overrides.yaml"
cat >"${demo_overrides}" <<EOF
dependency_overrides:
  universal_automation_interface:
    path: ../../universal_automation/pkgs/universal_automation_interface
  universal_automation_semantics:
    path: ../../universal_automation/pkgs/universal_automation_semantics
EOF

echo "prepare_universal_automation_sibling: wrote ${overrides} and ${demo_overrides}"
