#!/usr/bin/env bash
# Validate flutter_mcp_plugin/ surfaces:
# - required files exist
# - skill/command/agent files have parseable frontmatter with required fields
# - .mcp.json registers flutter-inspector
# - plugin version pin matches repo VERSION
# - marketplace manifest points at the plugin dir
#
# Wired into `make check-contracts`.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_DIR="$ROOT_DIR/flutter_mcp_plugin"
MARKET_FILE="$ROOT_DIR/.claude-plugin/marketplace.json"

fail() { echo "plugin-surfaces: $*" >&2; exit 1; }
ok()   { echo "plugin-surfaces: $*"; }

# 1. Required files
required_files=(
  "$PLUGIN_DIR/.claude-plugin/plugin.json"
  "$PLUGIN_DIR/.mcp.json"
  "$PLUGIN_DIR/README.md"
  "$PLUGIN_DIR/install.sh"
  "$PLUGIN_DIR/EXPECTED_SERVER_VERSION"
  "$PLUGIN_DIR/skills/flutter-mcp/SKILL.md"
  "$PLUGIN_DIR/skills/custom-toolkit-tools/SKILL.md"
  "$PLUGIN_DIR/commands/flutter-live-edit.md"
  "$PLUGIN_DIR/agents/flutter-inspector.md"
  "$MARKET_FILE"
)
for f in "${required_files[@]}"; do
  [[ -f "$f" ]] || fail "missing required file: ${f#$ROOT_DIR/}"
done
ok "required files present"

# 2. install.sh executable
[[ -x "$PLUGIN_DIR/install.sh" ]] || fail "install.sh is not executable"
ok "install.sh executable"

# 3. Frontmatter: each file must have '---' fences + description.
# Skills/agents also need 'name:'; commands derive name from filename.
check_frontmatter() {
  local file="$1"
  local require_name="$2"  # "yes" or "no"
  awk -v need_name="$require_name" '
    BEGIN { fences=0; found_name=0; found_desc=0 }
    /^---[[:space:]]*$/ { fences++; if (fences==2) exit; next }
    fences==1 && /^name:[[:space:]]*[^[:space:]]/ { found_name=1 }
    fences==1 && /^description:[[:space:]]*[^[:space:]]/ { found_desc=1 }
    END {
      if (fences < 2)                       { print "no_frontmatter"; exit }
      if (need_name=="yes" && !found_name)  { print "missing_name";   exit }
      if (!found_desc)                      { print "missing_desc";   exit }
      print "ok"
    }
  ' "$file"
}

while IFS='|' read -r file need_name; do
  result="$(check_frontmatter "$file" "$need_name")"
  [[ "$result" == "ok" ]] || fail "frontmatter issue ($result) in ${file#$ROOT_DIR/}"
done <<EOF
$PLUGIN_DIR/skills/flutter-mcp/SKILL.md|yes
$PLUGIN_DIR/skills/custom-toolkit-tools/SKILL.md|yes
$PLUGIN_DIR/agents/flutter-inspector.md|yes
$PLUGIN_DIR/commands/flutter-live-edit.md|no
EOF
ok "frontmatter valid in skills/command/agent"

# 4. .mcp.json registers flutter-inspector
if ! grep -q '"flutter-inspector"' "$PLUGIN_DIR/.mcp.json"; then
  fail ".mcp.json does not register 'flutter-inspector'"
fi
ok ".mcp.json registers flutter-inspector"

# 5. Version pin matches repo VERSION
repo_version="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
pin_version="$(tr -d '[:space:]' < "$PLUGIN_DIR/EXPECTED_SERVER_VERSION")"
if [[ "$repo_version" != "$pin_version" ]]; then
  fail "EXPECTED_SERVER_VERSION ($pin_version) != repo VERSION ($repo_version) — bump them together"
fi
ok "version pin matches repo VERSION ($repo_version)"

# 6. plugin.json name matches source dir name used in marketplace
if ! grep -q '"name"[[:space:]]*:[[:space:]]*"flutter-mcp"' "$PLUGIN_DIR/.claude-plugin/plugin.json"; then
  fail "plugin.json 'name' is not 'flutter-mcp'"
fi
if ! grep -q '"source"[[:space:]]*:[[:space:]]*"\./flutter_mcp_plugin"' "$MARKET_FILE"; then
  fail "marketplace.json does not point 'source' at ./flutter_mcp_plugin"
fi
ok "plugin.json <-> marketplace.json names aligned"

# 7. Skills reference MCP tool names (post-T8: prefixed `core_*`) that exist
# in the locked tool surface. Catches: plugin docs forgetting to prepend
# `core_`, or referencing a tool that was removed from the capability surface.
SURFACE_FILE="$ROOT_DIR/tool/contracts/expected_tool_surface.txt"
[[ -f "$SURFACE_FILE" ]] || fail "expected_tool_surface.txt not found"

tool_names=(
  "core_semantic_snapshot"
  "core_capture_ui_snapshot"
  "core_hot_reload_and_capture"
  "core_inspect_widget_at_point"
  "core_tap_widget"
  "core_enter_text"
)
for tool in "${tool_names[@]}"; do
  # Must appear in skill docs (promised to agents).
  if ! grep -Rq -- "$tool" "$PLUGIN_DIR/skills" "$PLUGIN_DIR/commands" "$PLUGIN_DIR/agents"; then
    fail "tool '$tool' not mentioned in plugin skills/commands/agents"
  fi
  # Must exist in the locked tool surface (snapshot file).
  if ! grep -qx -- "$tool" "$SURFACE_FILE"; then
    fail "tool '$tool' referenced by plugin but not in expected_tool_surface.txt"
  fi
done
ok "referenced MCP tool names ($(echo "${tool_names[*]}" | wc -w | tr -d ' ') checked) exist in locked surface"

echo "Plugin surfaces check passed."
