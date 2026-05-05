#!/usr/bin/env bash
# Validate plugin/ surfaces (Cursor, Codex, Claude Code marketplace):
# - required files exist
# - skill/agent files have parseable frontmatter with required fields
# - mcp.json registers the toolkit server under canonical key flutter-mcp-toolkit
#   OR legacy key flutter-inspector (user migration); command must be
#   flutter-mcp-toolkit-server (or FLUTTER_MCP_BIN defaulting to that name)
# - plugin version pin matches repo VERSION
# - marketplace manifest points at the plugin dir
#
# Wired into `make check-contracts`.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_DIR="$ROOT_DIR/plugin"
MARKET_FILE="$ROOT_DIR/.claude-plugin/marketplace.json"

fail() { echo "plugin-surfaces: $*" >&2; exit 1; }
ok()   { echo "plugin-surfaces: $*"; }

# 1. Required files
required_files=(
  "$PLUGIN_DIR/.claude-plugin/plugin.json"
  "$PLUGIN_DIR/.cursor-plugin/plugin.json"
  "$PLUGIN_DIR/.codex-plugin/plugin.json"
  "$PLUGIN_DIR/mcp.json"
  "$PLUGIN_DIR/README.md"
  "$PLUGIN_DIR/install.sh"
  "$PLUGIN_DIR/EXPECTED_SERVER_VERSION"
  "$PLUGIN_DIR/skills/flutter-mcp/SKILL.md"
  "$PLUGIN_DIR/skills/flutter-mcp-cli-runtime-validation/SKILL.md"
  "$PLUGIN_DIR/skills/flutter-mcp-toolkit-custom-tools/SKILL.md"
  "$PLUGIN_DIR/agents/flutter-mcp-toolkit-runtime.md"
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
$PLUGIN_DIR/skills/flutter-mcp-cli-runtime-validation/SKILL.md|yes
$PLUGIN_DIR/skills/flutter-mcp-toolkit-custom-tools/SKILL.md|yes
$PLUGIN_DIR/agents/flutter-mcp-toolkit-runtime.md|yes
EOF
ok "frontmatter valid in skills/agent"

# 4. mcp.json: canonical or legacy server id + correct binary
mcp_json="$PLUGIN_DIR/mcp.json"
if ! grep -qE '"flutter-mcp-toolkit"|"flutter-inspector"' "$mcp_json"; then
  fail "mcp.json must register mcpServers key 'flutter-mcp-toolkit' (canonical) or 'flutter-inspector' (legacy)"
fi
if ! grep -q 'flutter-mcp-toolkit-server' "$mcp_json"; then
  fail "mcp.json command must reference flutter-mcp-toolkit-server (see plugin/README.md)"
fi
ok "mcp.json registers toolkit server (flutter-mcp-toolkit or legacy flutter-inspector key)"

# 5. Version pin matches repo VERSION
repo_version="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
pin_version="$(tr -d '[:space:]' < "$PLUGIN_DIR/EXPECTED_SERVER_VERSION")"
if [[ "$repo_version" != "$pin_version" ]]; then
  fail "EXPECTED_SERVER_VERSION ($pin_version) != repo VERSION ($repo_version) — bump them together"
fi
ok "version pin matches repo VERSION ($repo_version)"

# 6. Claude + Cursor + Codex plugin.json name is flutter-mcp-toolkit
for manifest in "$PLUGIN_DIR/.claude-plugin/plugin.json" "$PLUGIN_DIR/.cursor-plugin/plugin.json" "$PLUGIN_DIR/.codex-plugin/plugin.json"; do
  if ! grep -q '"name"[[:space:]]*:[[:space:]]*"flutter-mcp-toolkit"' "$manifest"; then
    fail "$(basename "$(dirname "$manifest")")/plugin.json 'name' is not 'flutter-mcp-toolkit'"
  fi
done
if ! grep -q '"source"[[:space:]]*:[[:space:]]*"\./plugin"' "$MARKET_FILE"; then
  fail "marketplace.json does not point 'source' at ./plugin"
fi
ok "plugin manifests <-> marketplace.json aligned"

# 7. Skills reference MCP tool names (v3.0.0: prefixed `fmt_*`) that exist
# in the locked tool surface. Catches: plugin docs forgetting to prepend
# `fmt_`, or referencing a tool that was removed from the capability surface.
SURFACE_FILE="$ROOT_DIR/tool/contracts/expected_tool_surface.txt"
[[ -f "$SURFACE_FILE" ]] || fail "expected_tool_surface.txt not found"

tool_names=(
  "fmt_semantic_snapshot"
  "fmt_capture_ui_snapshot"
  "fmt_hot_reload_and_capture"
  "fmt_inspect_widget_at_point"
  "fmt_tap_widget"
  "fmt_enter_text"
)
for tool in "${tool_names[@]}"; do
  # Must appear in skill docs (promised to agents).
  if ! grep -Rq -- "$tool" "$PLUGIN_DIR/skills" "$PLUGIN_DIR/agents"; then
    fail "tool '$tool' not mentioned in plugin skills/agents"
  fi
  # Must exist in the locked tool surface (snapshot file).
  if ! grep -qx -- "$tool" "$SURFACE_FILE"; then
    fail "tool '$tool' referenced by plugin but not in expected_tool_surface.txt"
  fi
done
ok "referenced MCP tool names ($(echo "${tool_names[*]}" | wc -w | tr -d ' ') checked) exist in locked surface"

echo "Plugin surfaces check passed."
