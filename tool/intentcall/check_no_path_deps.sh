#!/usr/bin/env bash
# Fails if committed consumer pubspecs still use local intentcall path deps.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"

strict_root=false

usage() {
  cat <<'EOF'
Usage: tool/intentcall/check_no_path_deps.sh [--strict-root]

Default mode scans committed consumer packages and allows root dependency_overrides
used for deliberate local sibling development.

--strict-root additionally scans the root pubspec and lockfile. Use it before
publishing release/cutover changes that must not rely on local IntentCall paths.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict-root) strict_root=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown: $1" >&2; usage >&2; exit 64 ;;
  esac
done

found=0
patterns='agentkit/packages|intentcall/packages|path:[[:space:]]*.*intentcall'
matches_file="$(mktemp)"
trap 'rm -f "${matches_file}"' EXIT

check_versions() {
  python3 - "$@" <<'PY'
import re
import sys
from pathlib import Path

required_pubspec = "^0.2.1"
required_lock = "0.2.1"

def clean(value: str) -> str:
    value = value.strip()
    if value.startswith(("'", '"')) and value.endswith(("'", '"')):
        return value[1:-1]
    return value

def stanza(lines, start, indent):
    out = []
    for line in lines[start + 1:]:
        if not line.strip() or line.lstrip().startswith("#"):
            out.append(line)
            continue
        current_indent = len(line) - len(line.lstrip(" "))
        if current_indent <= indent:
            break
        out.append(line)
    return out

def find_version(lines, start, indent):
    for line in stanza(lines, start, indent):
        match = re.match(r"\s*version:\s*(.+?)\s*$", line)
        if match:
            return clean(match.group(1))
    return None

failed = False
for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    if not path.exists():
        continue
    lines = path.read_text().splitlines()
    expected = required_lock if path.name == "pubspec.lock" else required_pubspec
    for index, line in enumerate(lines):
        match = re.match(r"^(\s*)(intentcall_[A-Za-z0-9_]+):(?:\s*(.*?))?\s*$", line)
        if not match:
            continue
        indent = len(match.group(1))
        package = match.group(2)
        inline = clean(match.group(3) or "")
        version = inline if inline else find_version(lines, index, indent)
        if not version or version != expected:
            print(
                f"stale hosted intentcall version: {path}:{index + 1}: "
                f"{package} uses {version or '<missing>'}; expected {expected}",
                file=sys.stderr,
            )
            failed = True

raise SystemExit(1 if failed else 0)
PY
}

version_files=()
while IFS= read -r -d '' f; do
  version_files+=("$f")
  if grep -nE "${patterns}" "$f" >"${matches_file}" 2>/dev/null; then
    echo "path dep still present: $f" >&2
    echo "matched stale path pattern: agentkit/packages | intentcall/packages | path: .*intentcall" >&2
    cat "${matches_file}" >&2
    found=1
  fi
done < <(find mcp_toolkit mcp_server_dart packages flutter_test_app -name pubspec.yaml -print0 2>/dev/null)

if [[ "${strict_root}" == true ]]; then
  for f in pubspec.yaml pubspec.lock; do
    version_files+=("$f")
    if [[ -f "${f}" ]] && grep -nE "${patterns}" "$f" >"${matches_file}" 2>/dev/null; then
      echo "root path override still present: $f" >&2
      echo "matched release-blocking path pattern: agentkit/packages | intentcall/packages | path: .*intentcall" >&2
      cat "${matches_file}" >&2
      found=1
    fi
  done
fi

if ! check_versions "${version_files[@]}"; then
  found=1
fi

if [[ "${found}" -ne 0 ]]; then
  echo "FAIL: use hosted intentcall deps ^0.2.1 for committed consumer state (see docs/intentcall/README.md)" >&2
  exit 1
fi

if [[ "${strict_root}" == true ]]; then
  echo "OK: no intentcall path deps in consumers or root release state"
else
  echo "OK: no intentcall path deps in committed consumers (root local overrides not checked; run --strict-root before release/cutover)"
fi
