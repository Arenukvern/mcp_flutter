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
legacy_root="${repo_root}/.showcase/tool_verify/exec_sweep"
outdir="${legacy_root}/${platform}"
mkdir -p "${outdir}"

cleanup_legacy_root_artifacts() {
  local artifact
  for artifact in "${legacy_root}"/sweep_summary.txt \
    "${legacy_root}"/*.json \
    "${legacy_root}"/*.stderr; do
    [[ -e "${artifact}" ]] || continue
    rm -f "${artifact}"
  done
}

cleanup_legacy_root_artifacts

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
reveal_down_direction=down

json_ok() {
  python3 - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
data = d.get("data")
if not d.get("ok"):
    raise SystemExit(1)
if isinstance(data, dict) and (data.get("success") is False or data.get("ok") is False):
    raise SystemExit(1)
raise SystemExit(0)
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

missing_required_tool() {
  local name="$1"
  local reason="$2"
  printf 'FAIL: %s (%s)\n' "${name}" "${reason}"
  fail=$((fail + 1))
  results+=("FAIL ${name} (${reason})")
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

capture_snapshot() {
  local label="$1"
  local outfile="${outdir}/${label}.json"
  if "${toolkit[@]}" exec --name semantic_snapshot --args '{}' >"${outfile}" 2>"${outdir}/${label}.stderr" && json_ok "${outfile}"; then
    printf '%s\n' "${outfile}"
    return 0
  fi
  return 1
}

write_ref_args_for_identifier() {
  local snap_file="$1"
  local identifier="$2"
  local outfile="$3"
  local require_visible="${4:-true}"
  python3 - "${snap_file}" "${identifier}" "${outfile}" "${require_visible}" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
want = sys.argv[2]
out = sys.argv[3]
require_visible = sys.argv[4] == "true"
sid = d.get("data", {}).get("snapshot_id")
for node in d.get("data", {}).get("nodes", []):
    if node.get("identifier") != want or not node.get("ref"):
        continue
    if require_visible and node.get("centerInViewport") is not True:
        raise SystemExit(
            f"{want} found but center is outside viewport: {node.get('bounds')}"
        )
    json.dump({"ref": node["ref"], "snapshotId": sid}, open(out, "w"))
    raise SystemExit(0)
raise SystemExit(f"{want} not found")
PY
}

write_ref_args_for_type() {
  local snap_file="$1"
  local type_name="$2"
  local outfile="$3"
  python3 - "${snap_file}" "${type_name}" "${outfile}" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
want = sys.argv[2]
out = sys.argv[3]
sid = d.get("data", {}).get("snapshot_id")
for node in d.get("data", {}).get("nodes", []):
    if node.get("type") == want and node.get("ref"):
        json.dump({"ref": node["ref"], "snapshotId": sid}, open(out, "w"))
        raise SystemExit(0)
raise SystemExit(f"{want} not found")
PY
}

ensure_visible_identifier_args() {
  local identifier="$1"
  local outfile="$2"
  local direction="${3:-down}"
  local snap_file
  for attempt in 0 1 2 3 4 5 6; do
    snap_file="$(capture_snapshot "semantic_${identifier}_${attempt}")" || return 1
    if write_ref_args_for_identifier "${snap_file}" "${identifier}" "${outfile}" true 2>"${outdir}/${identifier}_${attempt}.visibility"; then
      return 0
    fi
    "${toolkit[@]}" exec --name scroll --args "{\"direction\":\"${direction}\",\"distance\":420}" >"${outdir}/scroll_to_${identifier}_${attempt}.json" 2>"${outdir}/scroll_to_${identifier}_${attempt}.stderr" || true
  done
  return 1
}

args_ref() {
  python3 - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(d["ref"])
PY
}

args_snapshot_id() {
  python3 - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(d["snapshotId"])
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

run_tool reveal_search "{\"query\":\"greeting_input_field\",\"matchBy\":\"identifier\",\"direction\":\"${reveal_down_direction}\",\"maxAttempts\":4,\"distance\":220}" || true
reveal_ref="$(json_field "${outdir}/reveal_search.json" data.ref)"
reveal_snap="$(json_field "${outdir}/reveal_search.json" data.snapshotId)"
reveal_visible="$(json_field "${outdir}/reveal_search.json" data.centerInViewport)"
if [[ -z "${reveal_ref}" ]]; then
  if ensure_visible_identifier_args greeting_input_field "${outdir}/greeting_args.json" "${reveal_down_direction}"; then
    reveal_ref="$(args_ref "${outdir}/greeting_args.json")"
    reveal_snap="$(args_snapshot_id "${outdir}/greeting_args.json")"
  fi
elif [[ "${reveal_visible}" != "True" && "${reveal_visible}" != "true" ]]; then
  if ensure_visible_identifier_args greeting_input_field "${outdir}/greeting_args.json" "${reveal_down_direction}"; then
    reveal_ref="$(args_ref "${outdir}/greeting_args.json")"
    reveal_snap="$(args_snapshot_id "${outdir}/greeting_args.json")"
  fi
fi

run_tool evaluate_dart_expression '{"expression":"AgentState.instance.greeting"}' || true
if [[ -n "${reveal_ref}" && -n "${reveal_snap}" ]]; then
  run_tool enter_text "{\"ref\":\"${reveal_ref}\",\"snapshotId\":${reveal_snap},\"text\":\"exec sweep\"}" || true
else
  missing_required_tool enter_text 'greeting_input_field ref not visible/discovered'
fi

if ensure_visible_identifier_args stateful_counter_increment_button "${outdir}/increment_tap_args.json" up; then
  run_tool tap_widget "$(cat "${outdir}/increment_tap_args.json")" || true
else
  missing_required_tool tap_widget 'stateful_counter_increment_button ref not visible/discovered'
fi
if ensure_visible_identifier_args stateful_counter_increment_button "${outdir}/increment_long_press_args.json" up; then
  if [[ "${platform}" == "web" ]]; then
    skip_tool long_press 'Flutter Web requires SemanticsAction.longPress on the target'
  else
    run_tool long_press "$(cat "${outdir}/increment_long_press_args.json")" || true
  fi
else
  missing_required_tool long_press 'stateful_counter_increment_button ref not visible/discovered'
fi
if ensure_visible_identifier_args stateful_counter_increment_button "${outdir}/increment_drag_args.json" up; then
  if [[ "${platform}" == "web" ]]; then
    skip_tool drag 'Flutter Web does not support semantic drag synthesis'
  else
    increment_ref="$(args_ref "${outdir}/increment_drag_args.json")"
    increment_snap="$(args_snapshot_id "${outdir}/increment_drag_args.json")"
    run_tool drag "{\"fromRef\":\"${increment_ref}\",\"toRef\":\"${increment_ref}\",\"snapshotId\":${increment_snap}}" || true
  fi
else
  missing_required_tool drag 'stateful_counter_increment_button ref not visible/discovered'
fi
if ensure_visible_identifier_args stateful_counter_increment_button "${outdir}/increment_hover_args.json" up; then
  run_tool hover "$(cat "${outdir}/increment_hover_args.json")" || true
else
  missing_required_tool hover 'stateful_counter_increment_button ref not visible/discovered'
fi

scroll_snap="$(capture_snapshot semantic_before_scroll || true)"
if [[ -n "${scroll_snap}" ]] && write_ref_args_for_type "${scroll_snap}" scrollable "${outdir}/scrollable_args.json" 2>/dev/null; then
  scroll_ref="$(args_ref "${outdir}/scrollable_args.json")"
  scroll_snap_id="$(args_snapshot_id "${outdir}/scrollable_args.json")"
  run_tool scroll "{\"ref\":\"${scroll_ref}\",\"direction\":\"down\",\"distance\":120,\"snapshotId\":${scroll_snap_id}}" || true
else
  missing_required_tool scroll 'scrollable ref not visible/discovered'
fi
scroll_snap="$(capture_snapshot semantic_before_swipe || true)"
if [[ -n "${scroll_snap}" ]] && write_ref_args_for_type "${scroll_snap}" scrollable "${outdir}/scrollable_swipe_args.json" 2>/dev/null; then
  scroll_ref="$(args_ref "${outdir}/scrollable_swipe_args.json")"
  scroll_snap_id="$(args_snapshot_id "${outdir}/scrollable_swipe_args.json")"
  run_tool swipe "{\"ref\":\"${scroll_ref}\",\"direction\":\"down\",\"distance\":80,\"snapshotId\":${scroll_snap_id}}" || true
else
  missing_required_tool swipe 'scrollable ref not visible/discovered'
fi
run_tool press_key '{"key":"Tab"}' || true
run_tool get_recent_logs '{"count":10}' || true
run_tool wait_for '{"predicate":{"kind":"time","ms":300},"timeoutMs":2000}' || true

# Navigation + dialog (requires showcaseNavigatorKey in flutter_test_app)
run_tool navigate '{"action":"push","route":"/visual-reconstruct"}' || true
if [[ "${platform}" == "web" ]]; then
  run_tool navigate '{"action":"push","route":"/"}' || true
else
  run_tool navigate '{"action":"pop"}' || true
fi
if ensure_visible_identifier_args show_test_dialog_button "${outdir}/dialog_args.json" "${reveal_down_direction}"; then
  run_tool tap_widget "$(cat "${outdir}/dialog_args.json")" || true
  sleep 0.5
  run_tool handle_dialog '{"action":"dismiss"}' || true
else
  missing_required_tool handle_dialog 'show_test_dialog_button ref not visible/discovered'
fi

if ensure_visible_identifier_args greeting_input_field "${outdir}/greeting_fill_args.json" up; then
  greeting_ref="$(args_ref "${outdir}/greeting_fill_args.json")"
  greeting_snap="$(args_snapshot_id "${outdir}/greeting_fill_args.json")"
  run_tool fill_form "{\"fields\":[{\"ref\":\"${greeting_ref}\",\"text\":\"fill form ok\"}],\"snapshotId\":${greeting_snap}}" || true
else
  missing_required_tool fill_form 'greeting_input_field ref not visible/discovered'
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
  printf 'generatedAt=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'script=%s\n' "${BASH_SOURCE[0]}"
  printf 'outdir=%s\n' "${outdir}"
  printf 'WS_URI=%s\n' "${ws_uri}"
  printf 'PASS=%s FAIL=%s SKIP=%s\n' "${pass}" "${fail}" "${skip}"
  printf '\nResults:\n'
  printf '%s\n' "${results[@]}"
} | tee "${summary_file}"

if [[ "${fail}" -gt 0 ]]; then
  exit 1
fi
