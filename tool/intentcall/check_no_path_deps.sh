#!/usr/bin/env bash
# Validates committed consumer pubspecs path-depend on sibling agentkit IntentCall packages.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"

strict_root=false

usage() {
  cat <<'EOF'
Usage: tool/intentcall/check_no_path_deps.sh [--strict-root]

Default mode scans committed consumer packages and requires local agentkit path
dependencies for every intentcall_* package.

--strict-root additionally scans the root pubspec and lockfile.
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
expected_path_suffix='agentkit/packages/intentcall_'

check_path_deps() {
  python3 - "$@" <<'PY'
import re
import sys
from pathlib import Path

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

def find_path(lines, start, indent):
    for line in stanza(lines, start, indent):
        match = re.match(r"\s*path:\s*(.+?)\s*$", line)
        if match:
            return clean(match.group(1))
    return None

def section_ranges(lines):
    ranges = []
    for index, line in enumerate(lines):
        match = re.match(r"^(dependencies|dev_dependencies|dependency_overrides):\s*$", line)
        if match:
            ranges.append((match.group(1), index))
    return ranges

def section_end(lines, start):
    for index in range(start + 1, len(lines)):
        line = lines[index]
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if re.match(r"^[A-Za-z0-9_]+:\s*$", line):
            return index
    return len(lines)

def in_dependency_section(index, lines, ranges):
    for _, start in ranges:
        end = section_end(lines, start)
        if start < index < end:
            return True
    return False

failed = False
for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    if not path.exists():
        continue
    lines = path.read_text().splitlines()
    dep_ranges = section_ranges(lines)
    for index, line in enumerate(lines):
        if not in_dependency_section(index, lines, dep_ranges):
            continue
        match = re.match(r"^  (intentcall_[A-Za-z0-9_]+):(?:\s*(.*?))?\s*$", line)
        if not match:
            continue
        package = match.group(1)
        inline = clean(match.group(2) or "")
        indent = 2
        block = stanza(lines, index, indent)
        dep_path = find_path(lines, index, indent)
        if inline and not dep_path:
            print(
                f"hosted intentcall dependency: {path}:{index + 1}: "
                f"{package} uses hosted {inline}; expected path to "
                f"agentkit/packages/{package}",
                file=sys.stderr,
            )
            failed = True
            continue
        if not dep_path:
            print(
                f"missing intentcall path dependency: {path}:{index + 1}: "
                f"{package} has no path: stanza",
                file=sys.stderr,
            )
            failed = True
            continue
        expected_suffix = f"agentkit/packages/{package}"
        if expected_suffix not in dep_path.replace("\\", "/"):
            print(
                f"unexpected intentcall path dependency: {path}:{index + 1}: "
                f"{package} -> {dep_path}; expected */{expected_suffix}",
                file=sys.stderr,
            )
            failed = True

raise SystemExit(1 if failed else 0)
PY
}

version_files=()
while IFS= read -r -d '' f; do
  version_files+=("$f")
done < <(find mcp_toolkit mcp_server_dart packages flutter_test_app jaspr_web_example -name pubspec.yaml -print0 2>/dev/null)

if [[ "${strict_root}" == true ]]; then
  for f in pubspec.yaml pubspec.lock; do
    [[ -f "${f}" ]] && version_files+=("$f")
  done
fi

if ! check_path_deps "${version_files[@]}"; then
  found=1
fi

if [[ "${found}" -ne 0 ]]; then
  echo "FAIL: committed consumers must path-depend on sibling agentkit intentcall_* packages (see docs/intentcall/README.md)" >&2
  exit 1
fi

if [[ "${strict_root}" == true ]]; then
  echo "OK: agentkit intentcall path deps in consumers and root release state"
else
  echo "OK: agentkit intentcall path deps in committed consumers (root not checked; run --strict-root for full gate)"
fi
