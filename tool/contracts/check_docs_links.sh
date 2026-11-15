#!/usr/bin/env bash
# Validates relative links in md/mdx and repo-path references in selected Dart sources.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "check_docs_links: $*" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "rg required"

broken=0

check_markdown_file() {
  local file="$1"
  local dir
  dir="$(dirname "$file")"
  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    if [[ "$link" == http:* || "$link" == https:* || "$link" == mailto:* || "$link" == \#* ]]; then
      continue
    fi
    # docs.page site-absolute paths (not filesystem paths)
    if [[ "$link" == /* ]]; then
      continue
    fi
    link="${link%%#*}"
    link="${link%%\?*}"
    [[ -z "$link" ]] && continue
    local target="$dir/$link"
    if [[ "$link" == dist/* ]]; then
      continue
    fi
    if [[ ! -e "$target" ]]; then
      echo "$file: broken link -> $link" >&2
      broken=1
    fi
  done < <(rg -o '\[[^]]*\]\(([^)]+)\)' -r '$1' "$file" 2>/dev/null || true)
}

while IFS= read -r f; do
  check_markdown_file "$f"
done < <(find docs -type f \( -name '*.md' -o -name '*.mdx' \) 2>/dev/null)

check_markdown_file README.md
check_markdown_file AGENTS.md
check_markdown_file CONTRIBUTING.md
check_markdown_file plugin/README.md

while IFS= read -r f; do
  while IFS= read -r path; do
    path="${path#./}"
    if [[ "$path" == docs/* ]] || [[ "$path" == *.md ]] || [[ "$path" == *.mdx ]]; then
      if [[ ! -e "$ROOT_DIR/$path" ]]; then
        echo "$f: broken doc path in source -> $path" >&2
        broken=1
      fi
    fi
  done < <(rg -o '(docs/[a-zA-Z0-9_./-]+\.(mdx?|md)|[A-Z_]+\.md)' "$f" 2>/dev/null || true)
  # Ignore historical path mentions inside link labels (href checked above).
done < <(rg -l 'docs/|QUICK_START|llm_install|start_here/' \
  mcp_toolkit/lib \
  mcp_server_dart/bin \
  mcp_server_dart/lib/src/shared_core/runner_control \
  showcase \
  2>/dev/null || true)

if ((broken != 0)); then
  fail "broken internal links detected"
fi

echo "check_docs_links: OK"