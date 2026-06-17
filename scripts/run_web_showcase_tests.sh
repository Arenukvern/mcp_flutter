#!/usr/bin/env bash
# Launch Chrome showcase, run the web validation battery, then tear down.
#
# Steps: doctor → validate-runtime → webmcp verify → runtime enter-text proof
#        → exec sweep (scripts/run_exec_sweep.sh).
#
# Artifacts: .showcase/tool_verify/web/
#
# For interactive debugging, use `make web-showcase` in one terminal and
# `make exec-sweep-web` in another instead of this all-in-one script.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
showcase="${repo_root}/.showcase"
log="${showcase}/web_app.log"
out="${showcase}/tool_verify/web"
web_port="${WEB_PORT:-8080}"
vm_port="${VM_HOST_PORT:-8181}"
mkdir -p "${out}"

printf '[web-tests] starting chrome showcase (detach)…\n'
bash "${repo_root}/scripts/run_web_showcase.sh" --detach

ws_uri=""
for _ in $(seq 1 30); do
  ws_uri="$(grep -Eo "ws://127\\.0\\.0\\.1:${vm_port}/[A-Za-z0-9_=-]+/ws" "${log}" | tail -1 || true)"
  if [[ -n "${ws_uri}" ]]; then break; fi
  sleep 1
done

if [[ -z "${ws_uri}" ]]; then
  printf '[web-tests] timeout reading WS_URI from %s\n' "${log}" >&2
  tail -40 "${log}" >&2
  bash "${repo_root}/scripts/stop_showcase.sh" 2>/dev/null || true
  exit 1
fi

printf '[web-tests] WS_URI=%s\n' "${ws_uri}"
export WS_URI="${ws_uri}"
export PLATFORM=web
export WEB_BROWSER_DEBUGGING_PORT="${WEB_BROWSER_DEBUGGING_PORT:-9222}"

toolkit=(dart run "${repo_root}/mcp_server_dart/bin/flutter_mcp_toolkit.dart" --vm-service-uri "${ws_uri}")

failures=0
run_step() {
  local name="$1"
  shift
  printf '\n[web-tests] === %s ===\n' "${name}"
  if "$@" >"${out}/${name}.stdout" 2>"${out}/${name}.stderr"; then
    printf '[web-tests] PASS %s\n' "${name}"
  else
    printf '[web-tests] FAIL %s (see %s)\n' "${name}" "${out}/${name}.stderr"
    failures=$((failures + 1))
  fi
}

run_step doctor "${toolkit[@]}" doctor --json
run_step validate-runtime "${toolkit[@]}" --flutter-device chrome --web-browser-debugging-port "${WEB_BROWSER_DEBUGGING_PORT}" \
  --save-images --output-dir "${out}/validate-runtime" \
  validate-runtime --target "${ws_uri}" --timeout-ms 60000
run_step webmcp-verify dart run "${repo_root}/mcp_server_dart/bin/flutter_mcp_toolkit.dart" webmcp verify --web-port "${web_port}"
run_step runtime-enter-text bash "${repo_root}/tool/evals/run_runtime_enter_text_greeting.sh" --ws-uri "${ws_uri}" \
  --platform web --launch-command "scripts/run_web_showcase.sh --detach" \
  --output "${out}/runtime-enter-text-greeting.json"
run_step exec-sweep bash "${repo_root}/scripts/run_exec_sweep.sh"

bash "${repo_root}/scripts/stop_showcase.sh" 2>/dev/null || true

{
  printf 'WS_URI=%s\n' "${ws_uri}"
  printf 'FAILURES=%s\n' "${failures}"
} | tee "${out}/summary.txt"

if [[ "${failures}" -gt 0 ]]; then
  exit 1
fi
printf '[web-tests] all web showcase tests passed\n'
