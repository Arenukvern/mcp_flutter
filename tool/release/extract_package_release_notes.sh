#!/usr/bin/env bash
# Extract a dart_changesets changelog section for GitHub release notes.
# Engine format: "## X.Y.Z" then "### Major|Minor|Patch Changes" (optional date
# on legacy "## [X.Y.Z] - YYYY-MM-DD" headings).
set -euo pipefail

fail() { echo "extract_package_release_notes: $*" >&2; exit 1; }

version="${1:-}"
changelog="${2:-}"

[[ -n "$version" ]] || fail "usage: extract_package_release_notes.sh <version> [changelog.md]"
[[ -n "$changelog" ]] || changelog="mcp_server_dart/CHANGELOG.md"
[[ -f "$changelog" ]] || changelog="mcp_toolkit/CHANGELOG.md"
[[ -f "$changelog" ]] || fail "missing changelog (tried mcp_server_dart and mcp_toolkit)"

awk -v version="$version" '
  function start_line(line,    v) {
    return line ~ ("^## \\[?" version "\\]?([ \t]+-.*)?$")
  }
  function next_section(line) {
    return line ~ /^## / && !start_line(line)
  }
  BEGIN { body = ""; in_section = 0 }
  {
    if (!in_section) {
      if (start_line($0)) {
        in_section = 1
      }
      next
    }
    if (next_section($0)) {
      exit
    }
    if (body != "") {
      body = body "\n" $0
    } else {
      body = $0
    }
  }
  END {
    gsub(/^[ \t\n]+|[ \t\n]+$/, "", body)
    if (body == "") {
      printf "Release %s.\n", version
    } else {
      print body
    }
  }
' "$changelog"