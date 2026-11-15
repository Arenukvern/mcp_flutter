#!/usr/bin/env bash
# Proves test_docs_links_fixtures.sh fails when check_docs_links.dart is weakened.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHECKER="$ROOT/tool/contracts/check_docs_links.dart"
FIXTURES="$ROOT/tool/contracts/test_docs_links_fixtures.sh"
BACKUP="$(mktemp)"

cp "$CHECKER" "$BACKUP"
restore() {
  cp "$BACKUP" "$CHECKER"
}
trap restore EXIT

apply_mutation() {
  local desc="$1"
  shift
  cp "$BACKUP" "$CHECKER"
  "$@"
  set +e
  bash "$FIXTURES" >/dev/null 2>&1
  local ec=$?
  set -e
  if ((ec == 0)); then
    echo "test_docs_links_checker_mutations: mutation '$desc' did not turn fixtures test red" >&2
    exit 1
  fi
  echo "mutation red: $desc"
}

# 1. drop mcp_server_dart/lib from scan list
apply_mutation "drop mcp_server_dart/lib" \
  perl -0pi -e "s/'mcp_server_dart\/lib',\n//" "$CHECKER"

# 2. drop plugin from walk roots and plugin/skills from scan list
apply_mutation "drop plugin walk and plugin/skills scan" \
  perl -0pi -e "s/'plugin', //g; s/'plugin\/skills',\n//" "$CHECKER"

# 3. early return before directory loop in scanTreeForLiterals
apply_mutation "scanTreeForLiterals early return" \
  perl -0pi -e 's/  for \(final f in Directory/  return;\n  for (final f in Directory/' "$CHECKER"

# 4. no-op walkDir (plugin/ markdown probes rely on this)
apply_mutation "no-op walkDir" \
  perl -0pi -e 's/(void walkDir\(String dir, void Function\(String path\) onFile\) \{\n)/$1  return;\n/' "$CHECKER"

# 5. not-found check != file (treat files as directories-only)
apply_mutation "scanTree not-found as not file" \
  perl -pi -e 's/entity == FileSystemEntityType.file/entity != FileSystemEntityType.file/' "$CHECKER"

# 6. existence check always found
apply_mutation "scanDocPathLiterals always found" \
  perl -pi -e 's/var found = false;/var found = true;/' "$CHECKER"

# 7. early return in scanDocPathLiterals
apply_mutation "scanDocPathLiterals no-op" \
  perl -0pi -e 's/void scanDocPathLiterals\(String path\) \{/void scanDocPathLiterals(String path) {\n  return;/' "$CHECKER"

echo "test_docs_links_checker_mutations: all 7 mutations turn fixtures test red"