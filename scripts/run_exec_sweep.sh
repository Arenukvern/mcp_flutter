#!/usr/bin/env bash
# Exec every default-surface MCP command against a running flutter_test_app showcase.
#
# Prerequisites:
#   macOS: make showcase-stop && make showcase  → export WS_URI from log
#   web:   make web-showcase                    → export WS_URI from log
#
# Usage:
#   export WS_URI='ws://127.0.0.1:8181/<token>/ws'
#   PLATFORM=macos bash scripts/run_exec_sweep.sh
#   PLATFORM=web WEB_BROWSER_DEBUGGING_PORT=9222 bash scripts/run_exec_sweep.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/.." && pwd)"
platform="${PLATFORM:-macos}"
ws_uri="${WS_URI:?Set WS_URI from make showcase or make web-showcase}"
outdir="${repo_root}/.showcase/tool_verify/exec_sweep/${platform}"
mkdir -p "${outdir}"

toolkit=(
  dart run "${repo_root}/mcp_server_dart/bin/flutter_mcp_toolkit.dart"
  --vm-service-uri "${ws_uri}"
)

case "${platform}" in
  macos)
    toolkit+=(--flutter-device macos --flutter-project-dir "${repo_root}/flutter_test_app")
    ;;
  web)
    toolkit+=(--flutter-device chrome --web-browser-debugging-port "${WEB_BROWSER_DEBUGGING_PORT:-9222}")
    ;;
  *)
    echo "Unsupported PLATFORM=${platform} (use macos or web)" >&2
    exit 64
    ;;
esac

pass=0
fail=0
skip=0
results=()

json_ok() {
  python3 - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
raise SystemExit(0 if d.get("ok") else 1)
PY
}

json_field() {
  python3 - "$1" "$2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
path = sys.argv[2].split(".")
cur = d
for part in path:
    if part == "":
        continue
    if isinstance(cur, dict):
        cur = cur.get(part)
    else:
        cur = None
        break
print("" if cur is None else cur)
PY
}

run_tool() {
  local name="$1"
  local args="${2-{\}}"
  local outfile="${outdir}/${name}.json"
  printf '=== %s ===\n' "${name}"
  if "${toolkit[@]}" exec --name "${name}" --args "${args}" >"${outfile}" 2>"${outdir}/${name}.stderr"; then
    if json_ok "${outfile}"; then
      printf 'PASS: %s\n' "${name}"
      pass=$((pass + 1))
      results+=("PASS ${name}")
      return 0
    fi
  fi
  printf 'FAIL: %s\n' "${name}"
  python3 - "${outfile}" <<'PY' 2>/dev/null || true
import json, sys
try:
  d = json.load(open(sys.argv[1]))
  print(d.get("error") or d)
except Exception as e:
  print(e)
PY
  fail=$((fail + 1))
  results+=("FAIL ${name}")
  return 1
}

skip_tool() {
  local name="$1"
  local reason="$2"
  printf 'SKIP: %s (%s)\n' "${name}" "${reason}"
  skip=$((skip + 1))
  results+=("SKIP ${name} (${reason})")
}

ref_for_identifier() {
  local snap_file="$1"
  local identifier="$2"
  python3 - "${snap_file}" "${identifier}" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
want = sys.argv[2]
for node in d.get("data", {}).get("nodes", []):
    if node.get("identifier") == want and node.get("ref"):
        print(node["ref"])
        raise SystemExit(0)
raise SystemExit(1)
PY
}

printf '[exec-sweep] platform=%s ws=%s out=%s\n' "${platform}" "${ws_uri}" "${outdir}"

# Discovery / VM
run_tool status '{}' || true
run_tool discover_debug_apps '{}' || true
run_tool get_vm '{}' || true
run_tool get_extension_rpcs '{}' || true
run_tool dynamicRegistryStats '{}' || true

# Inspection
run_tool get_app_errors '{"count":5}' || true
run_tool get_view_details '{}' || true
run_tool get_screenshots '{"compress":true,"mode":"flutter_layer"}' || true
run_tool inspect_widget_at_point '{"x":200,"y":300}' || true
run_tool capture_ui_snapshot '{"compress":true,"includeViewDetails":true,"includeErrors":true,"errorsCount":5}' || true
if [[ "${platform}" == "macos" ]]; then
  run_tool focus_window '{}' || true
else
  skip_tool focus_window 'macOS host only'
fi

# Semantic + interaction chain
run_tool semantic_snapshot '{}' || true
snap="$(json_field "${outdir}/semantic_snapshot.json" data.snapshot_id)"
increment_ref="$(ref_for_identifier "${outdir}/semantic_snapshot.json" stateful_counter_increment_button || echo s_9)"
scrollable_ref="$(ref_for_identifier "${outdir}/semantic_snapshot.json" showcase_scrollable || true)"
if [[ -z "${scrollable_ref}" ]]; then
  scrollable_ref="$(python3 - "${outdir}/semantic_snapshot.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for node in d.get("data", {}).get("nodes", []):
    if node.get("type") == "scrollable" and node.get("ref"):
        print(node["ref"])
        raise SystemExit(0)
print("s_21")
PY
)"
fi

run_tool reveal_search '{"query":"greeting_input_field","matchBy":"identifier","direction":"down","maxAttempts":4,"distance":220}' || true
reveal_ref="$(json_field "${outdir}/reveal_search.json" data.ref)"
reveal_snap="$(json_field "${outdir}/reveal_search.json" data.snapshotId)"
if [[ -z "${reveal_ref}" ]]; then
  reveal_ref="$(ref_for_identifier "${outdir}/semantic_snapshot.json" greeting_input_field || true)"
  reveal_snap="${snap}"
fi

run_tool evaluate_dart_expression '{"expression":"AgentState.instance.greeting"}' || true
if [[ -n "${reveal_ref}" && -n "${reveal_snap}" ]]; then
  run_tool enter_text "{\"ref\":\"${reveal_ref}\",\"snapshotId\":${reveal_snap},\"text\":\"exec sweep\"}" || true
fi
run_tool tap_widget "{\"ref\":\"${increment_ref}\",\"snapshotId\":${snap}}" || true
run_tool scroll "{\"ref\":\"${scrollable_ref}\",\"direction\":\"down\",\"distance\":120,\"snapshotId\":${snap}}" || true
run_tool long_press "{\"ref\":\"${increment_ref}\",\"snapshotId\":${snap}}" || true
run_tool swipe "{\"ref\":\"${scrollable_ref}\",\"direction\":\"down\",\"distance\":80,\"snapshotId\":${snap}}" || true
run_tool drag "{\"fromRef\":\"${increment_ref}\",\"toRef\":\"${increment_ref}\",\"snapshotId\":${snap}}" || true
run_tool hover "{\"ref\":\"${increment_ref}\",\"snapshotId\":${snap}}" || true
run_tool press_key '{"key":"Tab"}' || true
run_tool get_recent_logs '{"count":10}' || true
run_tool wait_for '{"predicate":{"kind":"time","ms":300},"timeoutMs":2000}' || true

# Navigation + dialog (requires showcaseNavigatorKey in flutter_test_app)
run_tool navigate '{"action":"push","route":"/visual-reconstruct"}' || true
run_tool navigate '{"action":"pop"}' || true
dialog_ref="$(ref_for_identifier "${outdir}/semantic_snapshot.json" show_test_dialog_button || true)"
if [[ -n "${dialog_ref}" ]]; then
  run_tool tap_widget "{\"ref\":\"${dialog_ref}\",\"snapshotId\":${snap}}" || true
  sleep 0.5
  run_tool handle_dialog '{"action":"dismiss"}' || true
else
  run_tool handle_dialog '{"action":"dismiss"}' || true
fi

greeting_ref="$(ref_for_identifier "${outdir}/semantic_snapshot.json" greeting_input_field || true)"
if [[ -n "${greeting_ref}" ]]; then
  run_tool fill_form "{\"fields\":[{\"ref\":\"${greeting_ref}\",\"text\":\"fill form ok\"}],\"snapshotId\":${snap}}" || true
fi

# Hot reload family (restart last — destructive)
run_tool hot_reload_flutter '{}' || true
run_tool hot_reload_and_capture '{"compress":true,"errorsCount":5}' || true

# Client bridge
run_tool fmt_list_client_tools_and_resources '{}' || true
run_tool fmt_client_tool '{"toolName":"dogfood_ping","arguments":{}}' || true

# migrate is a top-level subcommand, not exec
printf '=== migrate agent-entries ===\n'
if dart run "${repo_root}/mcp_server_dart/bin/flutter_mcp_toolkit.dart" migrate agent-entries --check "${repo_root}/flutter_test_app/lib" >"${outdir}/migrate_agent_entries.log" 2>&1; then
  printf 'PASS: migrate agent-entries\n'
  pass=$((pass + 1))
  results+=("PASS migrate agent-entries")
else
  printf 'FAIL: migrate agent-entries\n'
  fail=$((fail + 1))
  results+=("FAIL migrate agent-entries")
fi

run_tool hot_restart_flutter '{}' || true

summary_file="${outdir}/sweep_summary.txt"
{
  printf 'platform=%s\n' "${platform}"
  printf 'WS_URI=%s\n' "${ws_uri}"
  printf 'PASS=%s FAIL=%s SKIP=%s\n' "${pass}" "${fail}" "${skip}"
  printf '\nResults:\n'
  printf '%s\n' "${results[@]}"
} | tee "${summary_file}"

if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
