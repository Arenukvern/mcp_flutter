#!/usr/bin/env bash
# Validates IntentCall deps resolve to the sibling ../intentcall checkout.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"

strict_root=false

usage() {
  cat <<'EOF'
Usage: tool/intentcall/check_no_path_deps.sh [--strict-root]

Default mode scans committed consumer packages. A package may omit a version
when the workspace root dependency_overrides path points at ../intentcall.
A hosted version is rejected. An explicit path must end in
intentcall/packages/<package>.

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

def root_override_paths(repo_root: Path):
    pubspec = repo_root / "pubspec.yaml"
    if not pubspec.exists():
        return {}
    lines = pubspec.read_text().splitlines()
    ranges = section_ranges(lines)
    override_start = None
    for name, start in ranges:
        if name == "dependency_overrides":
            override_start = start
            break
    if override_start is None:
        return {}
    end = section_end(lines, override_start)
    paths = {}
    for index in range(override_start + 1, end):
        match = re.match(r"^  (intentcall_[A-Za-z0-9_]+):(?:\s*(.*?))?\s*$", lines[index])
        if not match:
            continue
        paths[match.group(1)] = find_path(lines, index, 2)
    return paths

repo_root = Path.cwd()
overrides = root_override_paths(repo_root)
failed = False
for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    if not path.exists() or path.name == "pubspec.lock":
        continue
    if path.resolve() == (repo_root / "pubspec.yaml").resolve():
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
        dep_path = find_path(lines, index, 2) or overrides.get(package)
        expected_suffix = f"intentcall/packages/{package}"
        if inline and find_path(lines, index, 2) is None:
            print(
                f"hosted intentcall dependency: {path}:{index + 1}: "
                f"{package} uses hosted {inline}; expected path to "
                f"{expected_suffix}",
                file=sys.stderr,
            )
            failed = True
            continue
        if not dep_path or expected_suffix not in dep_path.replace("\\", "/"):
            print(
                f"unexpected intentcall path dependency: {path}:{index + 1}: "
                f"{package} -> {dep_path or '<missing>'}; expected */{expected_suffix}",
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
  echo "FAIL: IntentCall deps must resolve through ../intentcall (see docs/intentcall/README.md)" >&2
  exit 1
fi

if [[ "${strict_root}" == true ]]; then
  echo "OK: intentcall sibling path deps in consumers and root release state"
else
  echo "OK: intentcall sibling path deps in committed consumers (root not checked; run --strict-root for full gate)"
fi
