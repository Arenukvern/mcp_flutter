#!/usr/bin/env bash
# Detect forbidden CirrusLabs Flutter *FROM* bases in Dockerfile.registry.
# Comment lines mentioning ghcr.io/cirruslabs/flutter must not trigger this guard.
#
# Returns 0 when a real FROM instruction references ghcr.io/cirruslabs/flutter.
# Returns 1 when no such FROM line exists.
dockerfile_registry_has_forbidden_cirruslabs_from() {
  local dockerfile="$1"
  [[ -f "$dockerfile" ]] || return 1
  grep -Eiq '^[[:space:]]*FROM[[:space:]]+(--[^[:space:]]+[[:space:]]+)*ghcr\.io/cirruslabs/flutter' \
    "$dockerfile"
}
