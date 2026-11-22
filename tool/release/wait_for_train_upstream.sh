#!/usr/bin/env bash
# Wait until the same-train dependency floors of a release-tagged package are
# visible on pub.dev before publishing that package.
#
# Per-tag publish runs are dispatched concurrently by the dart_changesets
# engine, but pub.dev validates a package's dependency constraints at upload
# time: publishing `kernel 8.0.0` (requires `core ^8.0.0`) fails until
# `core 8.0.0` is exposed. This script turns the train's dependency order into
# a wait, so every run converges regardless of dispatch order.
#
# Only the same-train `flutter_mcp_toolkit_*` family is waited on — external
# deps (intentcall_*, universal_*, oka_*) are long-published, and unconstrained
# or path deps are skipped.
#
# Usage:
#   tool/release/wait_for_train_upstream.sh --tag <pkg>-v<semver> \
#     [--package-dir <dir>] [--timeout-seconds <n>] [--pub-api-base <url>] \
#     [--pubspec <path>]
#
# --pubspec reads the manifest from a local file instead of the tag via
# `gh api` (used by the contract test fixture).
set -euo pipefail

PUB_API_BASE="${PUB_API_BASE:-https://pub.dev/api}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
POLL_SECONDS="${POLL_SECONDS:-15}"
TAG=""
PACKAGE_DIR=""
PUBSPEC_FILE=""

fail() { echo "wait_for_train_upstream: $*" >&2; exit 1; }
ok() { echo "wait_for_train_upstream: $*"; }

usage() {
  cat <<'USAGE'
Usage: tool/release/wait_for_train_upstream.sh --tag <pkg>-v<semver> \
  [--package-dir <dir>] [--pubspec <path>] \
  [--timeout-seconds <n>] [--pub-api-base <url>]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="${2:-}"; shift 2 ;;
    --package-dir) PACKAGE_DIR="${2:-}"; shift 2 ;;
    --pubspec) PUBSPEC_FILE="${2:-}"; shift 2 ;;
    --timeout-seconds) TIMEOUT_SECONDS="${2:-}"; shift 2 ;;
    --pub-api-base) PUB_API_BASE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
done

[[ "$TAG" =~ ^([A-Za-z0-9_]+)-v([0-9]+\.[0-9]+\.[0-9]+)$ ]] ||
  fail "tag must look like <package>-v<semver> (got '$TAG')"
PACKAGE="${BASH_REMATCH[1]}"
VERSION="${BASH_REMATCH[2]}"

# Package name -> manifest directory (release train layout). A case (not an
# associative array) keeps the script bash-3.2 compatible for local runs.
default_package_dir() {
  case "$1" in
    flutter_mcp_toolkit_server) echo "mcp_server_dart" ;;
    flutter_mcp_toolkit_core) echo "packages/core" ;;
    flutter_mcp_toolkit_capability_kernel) echo "packages/server_capability_kernel" ;;
    flutter_mcp_toolkit_capability_core) echo "packages/server_capability_core" ;;
    mcp_toolkit) echo "mcp_toolkit" ;;
    flutter_mcp_harness) echo "packages/harness" ;;
    *) return 1 ;;
  esac
}
if [[ -z "$PUBSPEC_FILE" ]]; then
  if [[ -z "$PACKAGE_DIR" ]]; then
    PACKAGE_DIR="$(default_package_dir "$PACKAGE")" ||
      fail "unknown package '$PACKAGE' (pass --package-dir)"
  fi
  [[ -n "${GITHUB_REPOSITORY:-}" ]] || fail "GITHUB_REPOSITORY required (or pass --pubspec)"
  command -v gh >/dev/null 2>&1 || fail "gh required (or pass --pubspec)"
  PUBSPEC_FILE="$(mktemp)"
  trap 'rm -f "$PUBSPEC_FILE"' EXIT
  gh api "repos/${GITHUB_REPOSITORY}/contents/${PACKAGE_DIR}/pubspec.yaml?ref=${TAG}" \
    --jq '.content' | base64 -d >"$PUBSPEC_FILE" ||
    fail "could not fetch ${PACKAGE_DIR}/pubspec.yaml at ${TAG}"
fi

# Same-train dependency floors: name -> minimum version (caret/exact floors
# only; unconstrained (null) and path deps are not waited on).
deps="$(
  python3 - "$PUBSPEC_FILE" <<'PY'
import re
import sys

lines = open(sys.argv[1], encoding="utf-8").read().splitlines()

section = None
out = []
for line in lines:
    header = re.match(r"^(dependencies|dev_dependencies|dependency_overrides):\s*$", line)
    if header:
        section = header.group(1)
        continue
    if re.match(r"^[A-Za-z0-9_]+:\s*$", line):
        section = None
        continue
    if section != "dependencies":
        continue
    match = re.match(r"^  (flutter_mcp_toolkit_[a-z0-9_]+):\s*(\^?[0-9][^\s#]*).*", line)
    if not match:
        continue
    name, constraint = match.group(1), match.group(2)
    floor = constraint.lstrip("^").split("+")[0]
    out.append(f"{name} {floor}")
print("\n".join(out))
PY
)"

if [[ -z "$deps" ]]; then
  ok "$PACKAGE $VERSION has no same-train dependency floors; nothing to wait for"
  exit 0
fi

deadline=$((SECONDS + TIMEOUT_SECONDS))
while IFS= read -r line; do
  dep="${line%% *}"
  floor="${line##* }"
  while true; do
    exposed="$(
      curl -fsSL --max-time 20 "${PUB_API_BASE}/packages/${dep}" 2>/dev/null |
        python3 -Ic "
import json, sys
try:
    versions = [v['version'] for v in json.load(sys.stdin)['versions']]
except Exception:
    versions = []
print('yes' if '${floor}' in versions else 'no')
" 2>/dev/null || echo no
    )"
    if [[ "$exposed" == "yes" ]]; then
      ok "$PACKAGE $VERSION: upstream $dep $floor is on pub.dev"
      break
    fi
    if (( SECONDS >= deadline )); then
      fail "$PACKAGE $VERSION: upstream $dep $floor never appeared on pub.dev within ${TIMEOUT_SECONDS}s"
    fi
    echo "waiting for $dep $floor on pub.dev (${SECONDS}s/${TIMEOUT_SECONDS}s)..."
    sleep "$POLL_SECONDS"
  done
done <<<"$deps"

ok "$PACKAGE $VERSION: all same-train upstream floors visible on pub.dev"
