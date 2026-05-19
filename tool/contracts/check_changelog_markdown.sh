#!/usr/bin/env bash
# Rejects CHANGELOG bullets that look like undefined reference links, e.g.
# [MCPCallEntry.resourceUri] instead of `MCPCallEntry.resourceUri`.
# Keep a Changelog headings (## [3.0.1]) are allowed via .markdownlint.json / MD052 disable.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHANGELOG="$ROOT_DIR/CHANGELOG.md"

fail() {
  echo "check_changelog_markdown: $*" >&2
  exit 1
}

ok() {
  echo "check_changelog_markdown: $*"
}

[[ -f "$CHANGELOG" ]] || fail "missing $CHANGELOG"

# [Identifier.member] not followed by ( — accidental reference link, not Keep a Changelog heading.
matches="$(perl -ne '
  next if /^## \[/;
  while (/\[([A-Za-z][A-Za-z0-9_]*\.[A-Za-z0-9_.]+)\](?!\()/g) {
    print "$.:$1\n";
  }
' "$CHANGELOG" || true)"

if [[ -n "$matches" ]]; then
  echo "CHANGELOG.md uses [Type.member] without a link target. Use backticks instead:" >&2
  echo "$matches" >&2
  fail "fix the lines above (see maintainer skill § Changelog workflow)"
fi

if ! head -5 "$CHANGELOG" | grep -q 'markdownlint-disable MD052'; then
  fail "CHANGELOG.md must keep <!-- markdownlint-disable MD052 --> after the title (Keep a Changelog headings)"
fi

ok "CHANGELOG.md markdown conventions OK"
