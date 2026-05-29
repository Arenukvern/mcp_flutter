#!/usr/bin/env bash
# Standard dogfood battery for MCP/intentcall tool quality.
# Rubric: docs/superpowers/evals/tool_quality_rubric.yaml
# Overview: docs/superpowers/evals/README.md
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
app_dir="${repo_root}/flutter_test_app"
showcase="${repo_root}/.showcase"
rubric="${repo_root}/docs/superpowers/evals/tool_quality_rubric.yaml"
tracker="${showcase}/dogfood_web_eval.yaml"
toolkit=(dart run "${repo_root}/mcp_server_dart/bin/flutter_mcp_toolkit.dart")

device=chrome
web_port=8080
vm_host_port=8181
ws_uri="${WS_URI:-}"
macos_ws_uri="${MACOS_WS_URI:-}"
run_macos=false
run_intentcall_tests=false
run_deconstruct_smoke=false
skip_runtime=false
skip_visual=false
merge_tracker=false
timeout_ms=45000
web_debug_port="${WEB_BROWSER_DEBUGGING_PORT:-}"
webmcp_verify=false
harness_root="${HARNESS_ROOT:-${repo_root}/../flutter_harness}"
visual_reconstruct_root="${VISUAL_RECONSTRUCT_ROOT:-${repo_root}/../flutter_visual_reconstruct}"
visual_hs="${VISUAL_HS:-${harness_root}/harness/examples/visual_reconstruct/warm_path_direct.hs.yaml}"
deconstruct_smoke_hs="${DECONSTRUCT_SMOKE_HS:-${harness_root}/harness/examples/visual_reconstruct/deconstruct_smoke.hs.yaml}"
deconstruct_golden="${app_dir}/test/goldens/visual_reconstruct.png"
ir_schema="${harness_root}/specs/ir_v0.schema.yaml"
visual_verdict="${harness_root}/harness/examples/visual_reconstruct/artifacts/verdict.yaml"

usage() {
  cat <<'EOF'
Usage: tool/evals/run_dogfood_eval.sh [options]

Runs the standard intentcall/MCP dogfood battery and writes scored YAML.

Options:
  --ws-uri URI              Web (chrome) VM websocket (or set WS_URI)
  --macos                   Also run validate-runtime for macOS showcase
  --macos-ws-uri URI        macOS VM websocket (or MACOS_WS_URI)
  --merge                   Merge iteration into .showcase/dogfood_web_eval.yaml (yq or dart)
  --run-intentcall-tests      dart test packages/intentcall_testing
  --run-deconstruct-smoke   Offline HS deconstruct_smoke.hs.yaml (needs fixture)
  --skip-runtime            Static checks only (no validate-runtime)
  --skip-visual             Skip HS warm-path visual_fidelity compare
  --timeout-ms MS           validate-runtime timeout (default 45000)
  --web-browser-debugging-port PORT  Chrome CDP port for web capture
  --webmcp-verify           After runtime, run webmcp verify (Chrome CDP)
  -h, --help                Show this help

Examples:
  export WS_URI='ws://127.0.0.1:8181/<token>/ws'
  bash tool/evals/run_dogfood_eval.sh --merge
  bash tool/evals/run_dogfood_eval.sh --skip-runtime
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ws-uri) ws_uri="$2"; shift 2 ;;
    --macos-ws-uri) macos_ws_uri="$2"; shift 2 ;;
    --macos) run_macos=true; shift ;;
    --merge) merge_tracker=true; shift ;;
    --run-intentcall-tests) run_intentcall_tests=true; shift ;;
    --run-deconstruct-smoke) run_deconstruct_smoke=true; shift ;;
    --skip-runtime) skip_runtime=true; shift ;;
    --skip-visual) skip_visual=true; shift ;;
    --timeout-ms) timeout_ms="$2"; shift 2 ;;
    --web-browser-debugging-port) web_debug_port="$2"; shift 2 ;;
    --webmcp-verify) webmcp_verify=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

run_id="$(date -u +%Y%m%dT%H%M%SZ)"
run_dir="${showcase}/eval_runs/${run_id}"
mkdir -p "${run_dir}"

log() { printf '[dogfood-eval] %s\n' "$*"; }

# --- static checks -----------------------------------------------------------
codegen_exit=0
init_exit=0
migrate_exit=0
intentcall_test_exit=0
deconstruct_static_exit=0
deconstruct_harness_exit=-1
deconstruct_cli_exit=-1

log "codegen sync --check (all platforms)"
set +e
"${toolkit[@]}" codegen sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir "${app_dir}" \
  --check >"${run_dir}/codegen_sync.log" 2>&1
codegen_exit=$?
set -e

log "init intentcall-platform --check"
set +e
"${toolkit[@]}" init intentcall-platform \
  --project-dir "${app_dir}" \
  --check >"${run_dir}/init_intentcall_platform.log" 2>&1
init_exit=$?
set -e

log "migrate agent-entries --check"
set +e
"${toolkit[@]}" migrate agent-entries \
  --check "${app_dir}/lib" >"${run_dir}/migrate_agent_entries.log" 2>&1
migrate_exit=$?
set -e

if [[ "${run_intentcall_tests}" == true ]]; then
  log "dart test packages/intentcall_testing"
  set +e
  intentcall_root="${INTENTCALL_ROOT:-}"
  if [[ -z "${intentcall_root}" ]]; then
    if [[ -d "${repo_root}/../agentkit/packages/intentcall_testing" ]]; then
      intentcall_root="${repo_root}/../agentkit"
    else
      intentcall_root="${repo_root}/intentcall"
    fi
  fi
  (cd "${intentcall_root}" && dart test packages/intentcall_testing) >"${run_dir}/intentcall_testing.log" 2>&1
  intentcall_test_exit=$?
  set -e
fi

# --- deconstruct static (Phase C; fast, no WS) ------------------------------
run_deconstruct_static() {
  log "deconstruct static: IR schema + golden + harness smoke fixture"
  set +e
  {
    [[ -f "${ir_schema}" ]] || {
      echo "missing ir_schema: ${ir_schema}"
      exit 2
    }
    [[ -f "${deconstruct_golden}" ]] || {
      echo "missing golden: ${deconstruct_golden}"
      exit 2
    }
    if [[ ! -f "${deconstruct_smoke_hs}" ]]; then
      echo "WARN: deconstruct_smoke.hs.yaml not found (C3 harness): ${deconstruct_smoke_hs}"
    else
      (cd "${harness_root}" && dart run bin/flutter_harness.dart lint "${deconstruct_smoke_hs}")
    fi
    if [[ -f "${visual_reconstruct_root}/bin/deconstruct.dart" ]]; then
      (cd "${visual_reconstruct_root}" &&
        dart run bin/deconstruct.dart lint --input "${deconstruct_golden}")
    elif [[ -f "${visual_reconstruct_root}/pubspec.yaml" ]] &&
      grep -qE '^[[:space:]]*deconstruct:' "${visual_reconstruct_root}/pubspec.yaml" 2>/dev/null; then
      (cd "${visual_reconstruct_root}" &&
        dart run deconstruct lint --input "${deconstruct_golden}")
    else
      echo "deconstruct CLI not present in ${visual_reconstruct_root} (C2 library — skipped)"
    fi
  } >"${run_dir}/deconstruct_static.log" 2>&1
  deconstruct_static_exit=$?
  set -e
  if [[ "${deconstruct_static_exit}" -ne 0 ]]; then
    warnings+=("deconstruct_static_failed")
  elif [[ ! -f "${deconstruct_smoke_hs}" ]]; then
    warnings+=("deconstruct_smoke_hs_pending")
  fi
}

run_deconstruct_smoke_harness() {
  if [[ ! -f "${deconstruct_smoke_hs}" ]]; then
    log "skip deconstruct smoke run: missing ${deconstruct_smoke_hs}"
    warnings+=("deconstruct_smoke_run_skipped")
    return 1
  fi
  local bundle="${run_dir}/deconstruct_smoke_bundle"
  mkdir -p "${bundle}"
  log "harness deconstruct smoke (offline) → ${bundle}"
  set +e
  (
    cd "${harness_root}" &&
      dart run bin/flutter_harness.dart lint "${deconstruct_smoke_hs}" &&
      dart run bin/flutter_harness.dart run "${deconstruct_smoke_hs}" \
        --bundle-dir "${bundle}"
  ) >"${run_dir}/deconstruct_smoke_run.log" 2>&1
  deconstruct_harness_exit=$?
  set -e
  [[ "${deconstruct_harness_exit}" -eq 0 ]] || warnings+=("deconstruct_smoke_run_failed")
  return "${deconstruct_harness_exit}"
}

run_deconstruct_static

if [[ "${run_deconstruct_smoke}" == true ]]; then
  run_deconstruct_smoke_harness || true
fi

# --- validate-runtime --------------------------------------------------------
vr_web_exit=-1
vr_web_ok=false
vr_macos_exit=-1
vr_macos_ok=false
vr_artifact=""
webmcp_verify_exit=-1
webmcp_probe_ok=false
extensions_ok=false
capture_ok=false
doctor_critical_pass=false
steps_failed=()
warnings=("visual_capture_truth_mode")
errors=()
fix_recommendations=()
capture_backend=""
capture_platform_views=""
dynamic_registry_tools=""
visual_harness_exit=-1
visual_compare_pass=false
visual_guild_weighted_score=""
visual_bundle_dir=""

json_get() {
  local file="$1"
  local filter="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r "${filter}" "${file}" 2>/dev/null || true
  else
    return 1
  fi
}

run_validate_runtime() {
  local label="$1"
  local target_uri="$2"
  local flutter_device="$3"
  local out_subdir="${run_dir}/${label}"
  mkdir -p "${out_subdir}"

  if [[ -z "${target_uri}" ]]; then
    log "skip validate-runtime (${label}): no WS URI"
    return 1
  fi

  local -a save_images_flag=()
  # Chrome CDP + embedded screenshots can hang >5m in CI/local dogfood; opt-in via env.
  if [[ "${flutter_device}" != chrome || "${DOGFOOD_SAVE_IMAGES:-}" == 1 ]]; then
    save_images_flag=(--save-images)
  fi
  local -a cmd=(
    "${toolkit[@]}"
    "${save_images_flag[@]}"
    --output-dir "${out_subdir}"
    validate-runtime
    --target "${target_uri}"
    --timeout-ms "${timeout_ms}"
    --flutter-device "${flutter_device}"
  )
  if [[ -n "${web_debug_port}" && "${flutter_device}" == chrome ]]; then
    cmd+=(--web-browser-debugging-port "${web_debug_port}")
  fi

  log "validate-runtime (${label}) → ${out_subdir}"
  set +e
  "${cmd[@]}" >"${out_subdir}/validate-runtime.stdout" 2>"${out_subdir}/validate-runtime.stderr"
  local exit_code=$?
  set -e

  if [[ -f "${out_subdir}/validate-runtime.json" ]]; then
    vr_artifact="${out_subdir}/validate-runtime.json"
    local root_ok=false summary_ok=false crit_ok=false cap_ok=false ext_status=fail
    if head -n 3 "${vr_artifact}" | grep -q '"ok": true'; then
      root_ok=true
    fi
    if grep -q '"criticalFailures": 0' "${vr_artifact}" 2>/dev/null; then
      crit_ok=true
    fi
    if grep -q 'Required toolkit extensions detected' "${vr_artifact}" 2>/dev/null; then
      ext_status=pass
    fi
    if grep -qE '"failed": 0' "${vr_artifact}" 2>/dev/null &&
      grep -qE '"success": [1-9]' "${vr_artifact}" 2>/dev/null; then
      summary_ok=true
    fi
    if grep -q '"captureBackend": "web_browser"' "${vr_artifact}" 2>/dev/null &&
      grep -q '"visualCaptureCommand": "capture_ui_snapshot"' "${vr_artifact}" 2>/dev/null; then
      cap_ok=true
    fi
    if command -v jq >/dev/null 2>&1; then
      capture_backend="$(json_get "${vr_artifact}" '.data.summary.captureBackend // empty')" || true
      capture_platform_views="$(json_get "${vr_artifact}" '.data.summary.capturePlatformViewsDetected // empty')" || true
      dynamic_registry_tools="$(json_get "${vr_artifact}" '.data.summary.dynamicRegistryToolCount // empty')" || true
    fi
    [[ -z "${capture_backend}" ]] && capture_backend="web_browser"
    [[ "${ext_status}" == pass ]] && extensions_ok=true || extensions_ok=false
    [[ "${crit_ok}" == true ]] && doctor_critical_pass=true || doctor_critical_pass=false
    [[ "${cap_ok}" == true ]] && capture_ok=true || capture_ok=false
    steps_failed=()
    [[ "${root_ok}" == true && "${summary_ok}" == true && "${exit_code}" -eq 0 ]] && return 0
  fi

  return "${exit_code}"
}

if [[ "${skip_runtime}" != true ]]; then
  if [[ -n "${ws_uri}" ]]; then
    set +e
    run_validate_runtime web "${ws_uri}" chrome
    vr_web_exit=$?
  [[ "${vr_web_exit}" -eq 0 ]] && vr_web_ok=true
    set -e
  else
    warnings+=("blocked_no_runtime_uri")
    log "no WS_URI / --ws-uri; runtime checks skipped"
  fi

  if [[ "${run_macos}" == true ]]; then
    set +e
    run_validate_runtime macos "${macos_ws_uri}" macos
    vr_macos_exit=$?
    [[ "${vr_macos_exit}" -eq 0 ]] && vr_macos_ok=true
    set -e
  fi

  if [[ "${webmcp_verify}" == true || "${device}" == chrome ]]; then
    log "webmcp verify (CDP probe for navigator.modelContext)"
    set +e
    webmcp_args=(webmcp verify --web-port "${web_port}")
    [[ -n "${web_debug_port}" ]] && webmcp_args+=(--cdp-port "${web_debug_port}")
    "${toolkit[@]}" "${webmcp_args[@]}" >"${run_dir}/webmcp_verify.json" 2>&1
    webmcp_verify_exit=$?
    set -e
    webmcp_probe_ok=false
    if [[ "${webmcp_verify_exit}" -eq 0 ]]; then
      webmcp_probe_ok=true
    else
      warnings+=("webmcp_inactive")
      fix_recommendations+=("Launch with: make web-showcase OR flutter-mcp-toolkit webmcp chrome-args")
    fi
  fi
fi

# --- visual fidelity (HS warm path + guild compare) --------------------------
run_visual_warm_path() {
  if [[ "${skip_visual}" == true ]]; then
    log "skip visual warm path (--skip-visual)"
    warnings+=("visual_fidelity_skipped")
    return 0
  fi
  if [[ ! -f "${visual_hs}" ]]; then
    log "skip visual warm path: missing ${visual_hs} (set HARNESS_ROOT)"
    warnings+=("visual_fidelity_skipped")
    return 0
  fi
  if [[ -z "${ws_uri}" ]]; then
    log "skip visual warm path: no WS_URI"
    warnings+=("visual_fidelity_skipped")
    return 0
  fi

  visual_bundle_dir="${run_dir}/visual_reconstruct_bundle"
  mkdir -p "${visual_bundle_dir}"

  log "harness warm path → ${visual_bundle_dir}"
  set +e
  (
    cd "${harness_root}" &&
      dart run bin/flutter_harness.dart lint "${visual_hs}" &&
      dart run bin/flutter_harness.dart --save-images run "${visual_hs}" \
        --connection uri \
        --vm-service-uri "${ws_uri}" \
        --bundle-dir "${visual_bundle_dir}"
  ) >"${run_dir}/visual_warm_path.log" 2>&1
  visual_harness_exit=$?
  set -e

  local verdict_for_eval="${visual_verdict}"
  if [[ -f "${visual_bundle_dir}/visual_verdict.yaml" ]]; then
    verdict_for_eval="${visual_bundle_dir}/visual_verdict.yaml"
    cp -f "${verdict_for_eval}" "${run_dir}/visual_verdict.yaml" 2>/dev/null || true
  elif [[ -f "${visual_verdict}" ]]; then
    cp -f "${visual_verdict}" "${run_dir}/visual_verdict.yaml" 2>/dev/null || true
  fi
  if [[ -f "${verdict_for_eval}" ]] && grep -qE '^pass:[[:space:]]*true' "${verdict_for_eval}"; then
    visual_compare_pass=true
  fi
  if command -v yq >/dev/null 2>&1 && [[ -f "${verdict_for_eval}" ]]; then
    visual_guild_weighted_score="$(yq '.guild_score.weighted_score // ""' "${verdict_for_eval}" 2>/dev/null || true)"
  elif [[ -f "${verdict_for_eval}" ]]; then
    visual_guild_weighted_score="$(grep -E 'weighted_score:' "${verdict_for_eval}" | head -1 | awk '{print $2}' || true)"
  fi

  if [[ "${visual_harness_exit}" -ne 0 ]]; then
    warnings+=("visual_warm_path_failed")
    errors+=("visual_fidelity_harness_failed")
  elif [[ "${visual_compare_pass}" != true ]]; then
    warnings+=("visual_compare_not_pass")
    errors+=("visual_fidelity_compare_failed")
  fi
  return 0
}

if [[ "${skip_runtime}" != true ]]; then
  run_visual_warm_path
fi

# --- scoring (rubric v1 weights) ---------------------------------------------
dim_connectivity=0
dim_schema=0
dim_handler=0
dim_capture=0
dim_visual=0
dim_webmcp=0
dim_authoring=0
dim_docs=10

if [[ "${skip_runtime}" != true && -n "${ws_uri}" ]]; then
  if [[ "${vr_web_ok}" == true && "${doctor_critical_pass}" == true ]]; then
    dim_connectivity=20
  elif [[ "${extensions_ok}" == true ]]; then
    dim_connectivity=12
  elif [[ "${vr_web_exit}" -ge 0 ]]; then
    dim_connectivity=4
  fi

  [[ "${vr_web_ok}" == true ]] && dim_schema=10 || dim_schema=0

  if [[ "${vr_web_ok}" == true && "${#steps_failed[@]}" -eq 0 ]]; then
    dim_handler=20
  elif [[ "${vr_web_exit}" -eq 0 ]]; then
    dim_handler=16
  elif [[ "${vr_web_exit}" -ge 0 ]]; then
    dim_handler=8
  fi

  [[ "${capture_ok}" == true ]] && dim_capture=10 || dim_capture=5

  if [[ "${visual_compare_pass}" == true && "${visual_harness_exit}" -eq 0 ]]; then
    dim_visual=10
  elif [[ "${visual_harness_exit}" -ge 0 && "${visual_compare_pass}" == true ]]; then
    dim_visual=8
  elif [[ "${visual_harness_exit}" -ge 0 ]]; then
    dim_visual=4
  fi
  if printf '%s\n' "${warnings[@]}" | grep -qx 'visual_fidelity_skipped'; then
    dim_visual=0
  fi

  dim_webmcp=0
  [[ "${codegen_exit}" -eq 0 ]] && dim_webmcp=8
  [[ "${webmcp_probe_ok}" == true ]] && dim_webmcp=10
  [[ "${webmcp_probe_ok}" != true && "${vr_web_ok}" == true && "${capture_backend}" == web_browser ]] && dim_webmcp=8
elif [[ "${skip_runtime}" == true ]]; then
  dim_webmcp=0
  [[ "${codegen_exit}" -eq 0 ]] && dim_webmcp=8
fi

dim_authoring=0
[[ "${init_exit}" -eq 0 ]] && dim_authoring=$((dim_authoring + 4))
[[ "${codegen_exit}" -eq 0 ]] && dim_authoring=$((dim_authoring + 3))
[[ "${migrate_exit}" -eq 0 ]] && dim_authoring=$((dim_authoring + 3))

if [[ "${run_intentcall_tests}" == true ]]; then
  [[ "${intentcall_test_exit}" -eq 0 ]] && dim_handler=20 || dim_handler=$((dim_handler > 4 ? dim_handler - 4 : 0))
fi

# docs_truth: start full; deduct for known recurring warnings present this run
for w in fmt_get_recent_logs_unsupported_cli exec_fmt_prefix_confusion; do
  for existing in "${warnings[@]}"; do
    [[ "${existing}" == "${w}" ]] && dim_docs=$((dim_docs - 3))
  done
done
(( dim_docs < 0 )) && dim_docs=0

score=$((dim_connectivity + dim_schema + dim_handler + dim_capture + dim_visual + dim_webmcp + dim_authoring + dim_docs))
(( score > 100 )) && score=100

verdict=fail
if [[ "${skip_runtime}" == true ]]; then
  if [[ "${codegen_exit}" -eq 0 && "${init_exit}" -eq 0 && "${migrate_exit}" -eq 0 ]]; then
    verdict=blocked_no_runtime
  fi
elif [[ "${score}" -ge 80 ]]; then
  if [[ "${#warnings[@]}" -gt 0 ]]; then
    verdict=pass_with_warnings
  else
    verdict=pass
  fi
else
  verdict=fail
fi

# --- errors list -------------------------------------------------------------
[[ "${codegen_exit}" -ne 0 ]] && errors+=("codegen_sync_check_failed")
[[ "${init_exit}" -ne 0 ]] && errors+=("init_intentcall_platform_failed")
[[ "${migrate_exit}" -ne 0 ]] && errors+=("migrate_agent_entries_failed")
[[ "${skip_runtime}" != true && -z "${ws_uri}" ]] && errors+=("missing_ws_uri")
[[ "${skip_runtime}" != true && -n "${ws_uri}" && "${vr_web_ok}" != true ]] && errors+=("validate_runtime_web_failed")
[[ "${skip_runtime}" != true && "${webmcp_verify_exit}" -ge 0 && "${webmcp_probe_ok}" != true ]] && warnings+=("webmcp_verify_failed")
[[ "${run_intentcall_tests}" == true && "${intentcall_test_exit}" -ne 0 ]] && errors+=("intentcall_testing_failed")

# --- YAML writers ------------------------------------------------------------
yaml_list() {
  local name="$1"
  shift
  printf '%s:\n' "${name}"
  if [[ $# -eq 0 ]]; then
    printf '  []\n'
    return
  fi
  local item
  for item in "$@"; do
    printf '  - %s\n' "${item}"
  done
}

write_eval_run() {
  local dest="$1"
  {
    printf '# Dogfood eval run — generated by tool/evals/run_dogfood_eval.sh\n'
    printf '# Rubric: docs/superpowers/evals/tool_quality_rubric.yaml\n\n'
    printf 'run_id: "%s"\n' "${run_id}"
    printf 'rubric: docs/superpowers/evals/tool_quality_rubric.yaml\n'
    printf 'program: flutter_test_app_web_dogfood\n'
    printf 'device: %s\n' "${device}"
    printf 'web_port: %s\n' "${web_port}"
    printf 'vm_host_port: %s\n' "${vm_host_port}"
    printf 'started_at: "%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    [[ -n "${ws_uri}" ]] && printf 'ws_uri: %s\n' "${ws_uri}"
    printf 'score: %s\n' "${score}"
    printf 'verdict: %s\n\n' "${verdict}"
    printf 'dimension_scores:\n'
    printf '  connectivity: %s\n' "${dim_connectivity}"
    printf '  schema_validity: %s\n' "${dim_schema}"
    printf '  handler_correctness: %s\n' "${dim_handler}"
    printf '  capture_quality: %s\n' "${dim_capture}"
    printf '  visual_fidelity: %s\n' "${dim_visual}"
    printf '  webmcp_parity: %s\n' "${dim_webmcp}"
    printf '  intentcall_authoring: %s\n' "${dim_authoring}"
    printf '  docs_truth: %s\n\n' "${dim_docs}"
    printf 'checks:\n'
    printf '  codegen_sync: { exit: %s, ok: %s, log: %s }\n' \
      "${codegen_exit}" "$([[ "${codegen_exit}" -eq 0 ]] && echo true || echo false)" \
      "${run_dir}/codegen_sync.log"
    printf '  init_intentcall_platform: { exit: %s, ok: %s, log: %s }\n' \
      "${init_exit}" "$([[ "${init_exit}" -eq 0 ]] && echo true || echo false)" \
      "${run_dir}/init_intentcall_platform.log"
    printf '  migrate_agent_entries: { exit: %s, ok: %s, log: %s }\n' \
      "${migrate_exit}" "$([[ "${migrate_exit}" -eq 0 ]] && echo true || echo false)" \
      "${run_dir}/migrate_agent_entries.log"
    if [[ "${run_intentcall_tests}" == true ]]; then
      printf '  intentcall_testing: { exit: %s, ok: %s, log: %s }\n' \
        "${intentcall_test_exit}" "$([[ "${intentcall_test_exit}" -eq 0 ]] && echo true || echo false)" \
        "${run_dir}/intentcall_testing.log"
    fi
    printf '  deconstruct_static: { exit: %s, ok: %s, log: %s }\n' \
      "${deconstruct_static_exit}" "$([[ "${deconstruct_static_exit}" -eq 0 ]] && echo true || echo false)" \
      "${run_dir}/deconstruct_static.log"
    if [[ "${deconstruct_harness_exit}" -ge 0 ]]; then
      printf '  deconstruct_smoke_run: { exit: %s, ok: %s, log: %s }\n' \
        "${deconstruct_harness_exit}" "$([[ "${deconstruct_harness_exit}" -eq 0 ]] && echo true || echo false)" \
        "${run_dir}/deconstruct_smoke_run.log"
    fi
    if [[ -n "${vr_artifact}" ]]; then
      printf '  validate_runtime: { exit: %s, ok: %s, artifact: %s }\n' \
        "${vr_web_exit}" "${vr_web_ok}" "${vr_artifact}"
    fi
    if [[ "${webmcp_verify_exit}" -ge 0 ]]; then
      printf '  webmcp_verify: { exit: %s, ok: %s, log: %s }\n' \
        "${webmcp_verify_exit}" "${webmcp_probe_ok}" "${run_dir}/webmcp_verify.json"
    fi
    if [[ "${visual_harness_exit}" -ge 0 ]]; then
      printf '  visual_warm_path: { exit: %s, ok: %s, verdict: %s, log: %s }\n' \
        "${visual_harness_exit}" "${visual_compare_pass}" "${visual_verdict}" \
        "${run_dir}/visual_warm_path.log"
    fi
    printf '\n'
    printf '# Legacy-compatible fields (iterations 1–4 mapping)\n'
    printf 'validate_runtime_ok: %s\n' "$([[ "${vr_web_ok}" == true ]] && echo true || echo false)"
    printf 'doctor_critical_pass: %s\n' "${doctor_critical_pass}"
    printf 'extensions_ok: %s\n' "${extensions_ok}"
    printf 'capture_ok: %s\n' "${capture_ok}"
    printf 'intentcall_hooks_ok: %s\n' "$([[ "${init_exit}" -eq 0 && "${codegen_exit}" -eq 0 ]] && echo true || echo false)"
    [[ -n "${capture_backend}" ]] && printf 'captureBackend: %s\n' "${capture_backend}"
    [[ -n "${dynamic_registry_tools}" ]] && printf 'dynamic_registry_tools: %s\n' "${dynamic_registry_tools}"
    printf 'visual_compare_pass: %s\n' "${visual_compare_pass}"
    [[ -n "${visual_guild_weighted_score}" ]] && printf 'visual_guild_weighted_score: %s\n' "${visual_guild_weighted_score}"
    [[ "${visual_harness_exit}" -ge 0 ]] && printf 'visual_harness_exit: %s\n' "${visual_harness_exit}"
    [[ -n "${visual_bundle_dir}" ]] && printf 'visual_bundle_dir: %s\n' "${visual_bundle_dir}"
    printf '\n'
    if [[ ${#errors[@]} -gt 0 ]]; then
      yaml_list errors "${errors[@]}"
    else
      printf 'errors: []\n'
    fi
    yaml_list warnings "${warnings[@]}"
    printf 'recurring_errors: []\n'
    printf 'recurring_warnings: []\n'
    printf 'fix_recommendations: []\n'
    printf 'artifacts_dir: %s\n' "${run_dir}"
  } >"${dest}"
}

eval_snapshot="${showcase}/eval_run_${run_id}.yaml"
write_eval_run "${run_dir}/eval_run.yaml"
write_eval_run "${eval_snapshot}"

log "wrote ${run_dir}/eval_run.yaml"
log "wrote ${eval_snapshot}"
log "score=${score} verdict=${verdict}"

# --- merge into dogfood tracker ----------------------------------------------
if [[ "${merge_tracker}" == true ]]; then
  if [[ ! -f "${tracker}" ]]; then
    log "WARN: tracker missing at ${tracker}; skip merge"
    exit 0
  fi

  if command -v yq >/dev/null 2>&1; then
    next_iter="$(yq '.iterations | length' "${tracker}")"
  else
    next_iter="$(grep -cE '^  - iteration:' "${tracker}" || true)"
  fi
  next_iter=$((next_iter + 1))

  iteration_yaml="${run_dir}/iteration_merge.yaml"
  {
    printf 'iteration: %s\n' "${next_iter}"
    printf 'ran_at: "%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'score: %s\n' "${score}"
    printf 'verdict: %s\n' "${verdict}"
    printf 'validate_runtime_ok: %s\n' "$([[ "${vr_web_ok}" == true ]] && echo true || echo false)"
    printf 'doctor_critical_pass: %s\n' "${doctor_critical_pass}"
    printf 'extensions_ok: %s\n' "${extensions_ok}"
    printf 'capture_ok: %s\n' "${capture_ok}"
    printf 'intentcall_hooks_ok: %s\n' "$([[ "${init_exit}" -eq 0 && "${codegen_exit}" -eq 0 ]] && echo true || echo false)"
    [[ -n "${ws_uri}" ]] && printf 'ws_uri: %s\n' "${ws_uri}"
    [[ -n "${capture_backend}" ]] && printf 'captureBackend: %s\n' "${capture_backend}"
    printf 'dimension_scores:\n'
    printf '  connectivity: %s\n' "${dim_connectivity}"
    printf '  schema_validity: %s\n' "${dim_schema}"
    printf '  handler_correctness: %s\n' "${dim_handler}"
    printf '  capture_quality: %s\n' "${dim_capture}"
    printf '  visual_fidelity: %s\n' "${dim_visual}"
    printf '  webmcp_parity: %s\n' "${dim_webmcp}"
    printf '  intentcall_authoring: %s\n' "${dim_authoring}"
    printf '  docs_truth: %s\n' "${dim_docs}"
    printf 'visual_compare_pass: %s\n' "${visual_compare_pass}"
    [[ -n "${visual_guild_weighted_score}" ]] && printf 'visual_guild_weighted_score: %s\n' "${visual_guild_weighted_score}"
    if [[ ${#errors[@]} -gt 0 ]]; then
      yaml_list errors "${errors[@]}"
    else
      printf 'errors: []\n'
    fi
    yaml_list warnings "${warnings[@]}"
    printf 'artifacts:\n  - %s/eval_run.yaml\n' "${run_dir}"
  } >"${iteration_yaml}"

  if command -v yq >/dev/null 2>&1; then
    next_iter="$(yq '.iterations | length' "${tracker}")"
    next_iter=$((next_iter + 1))
    yq -i ".iterations += [load(\"${iteration_yaml}\")]" "${tracker}"
    yq -i ".summary.iterations_count = (.iterations | length)" "${tracker}"
    yq -i '.summary.best_score = ([.iterations[].score] | max)' "${tracker}"
    yq -i '.summary.worst_score = ([.iterations[].score] | min)' "${tracker}"
    yq -i '.summary.mean_score = (([.iterations[].score] | add) / ([.iterations[].score] | length))' "${tracker}"
    yq -i ".summary.verdict = \"${verdict}\"" "${tracker}"
    yq -i ".scoring.rubric = \"docs/superpowers/evals/tool_quality_rubric.yaml\"" "${tracker}"
    log "merged iteration ${next_iter} into ${tracker} (yq)"
  else
  dart run "${repo_root}/mcp_server_dart/tool/merge_dogfood_tracker.dart" \
    "${tracker}" "${iteration_yaml}" "${verdict}"
    log "merged into ${tracker} (dart)"
  fi
fi

# Exit non-zero if battery failed
[[ "${verdict}" == pass || "${verdict}" == pass_with_warnings || "${verdict}" == blocked_no_runtime ]] || exit 1
[[ "${codegen_exit}" -eq 0 && "${init_exit}" -eq 0 && "${migrate_exit}" -eq 0 ]] || exit 1
[[ "${skip_runtime}" == true || "${vr_web_ok}" == true ]] || exit 1
