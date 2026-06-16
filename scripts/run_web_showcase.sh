#!/usr/bin/env bash
# Run flutter_test_app on Chrome with WebMCP-enabling browser flags.
# Prints VM ws URI when ready. Logs: .showcase/web_app.log
#
# Modes:
#   default  — foreground; blocks until flutter exits (interactive hot reload)
#   --detach — background; prints WS_URI and exits (for run_web_showcase_tests.sh)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/.." && pwd)"
app_dir="${repo_root}/flutter_test_app"
showcase_dir="${repo_root}/.showcase"
log="${showcase_dir}/web_app.log"
pid_file="${showcase_dir}/web_flutter.pid"

web_port="${WEB_PORT:-8080}"
vm_port="${VM_HOST_PORT:-8181}"
flutter_route="${FLUTTER_ROUTE:-}"
dogfood_visual="${DOGFOOD_VISUAL:-}"
detach=false

usage() {
  cat <<'EOF'
Usage: scripts/run_web_showcase.sh [--detach]

  --detach  Start Chrome showcase in background, print WS_URI, exit (app keeps running)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --detach) detach=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

bash "${here}/stop_showcase.sh" 2>/dev/null || true
mkdir -p "${showcase_dir}"

printf '[web-showcase] Chrome :%s with WebMCP flags → %s\n' "${web_port}" "${log}"
[[ -n "${flutter_route}" ]] && printf '[web-showcase] route=%s\n' "${flutter_route}"
printf '[web-showcase] recipe: dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart webmcp chrome-args\n\n'

cd "${app_dir}"

route_args=()
dart_define_args=()
if [[ -n "${flutter_route}" ]]; then
  route_args=(--route="${flutter_route}")
  printf '[web-showcase] FLUTTER_ROUTE=%s\n' "${flutter_route}"
fi
if [[ "${dogfood_visual}" == "1" || "${dogfood_visual}" == "true" ]]; then
  dart_define_args=(--dart-define=DOGFOOD_VISUAL=true)
  printf '[web-showcase] DOGFOOD_VISUAL=true (initialRoute /visual-reconstruct)\n'
fi

flutter_args=(
  run -d chrome
  --web-port="${web_port}"
  --host-vmservice-port="${vm_port}"
  "${route_args[@]}"
  "${dart_define_args[@]}"
  --debug
  --web-browser-flag="--enable-features=WebModelContext"
  --web-browser-flag="--enable-experimental-web-platform-features"
)

if [[ "${detach}" == true ]]; then
  : >"${log}"
  nohup flutter "${flutter_args[@]}" >>"${log}" 2>&1 < /dev/null &
  fpid=$!
  disown "${fpid}" 2>/dev/null || true
else
  flutter "${flutter_args[@]}" 2>&1 | tee "${log}" &
  fpid=$!
fi

echo "${fpid}" > "${pid_file}"
printf '[web-showcase] flutter pid %s\n' "${fpid}"

ws_uri=""
ready_pattern='Flutter run key commands'
for _ in $(seq 1 180); do
  if [[ "${detach}" == true ]] && ! kill -0 "${fpid}" 2>/dev/null; then
    printf '\n[web-showcase] flutter exited before VM ws URI appeared\n' >&2
    tail -40 "${log}" >&2
    exit 1
  fi
  ws_uri="$(grep -Eo 'ws://127\.0\.0\.1:[0-9]+/[A-Za-z0-9_=-]+/ws' "${log}" | tail -1 || true)"
  if [[ -n "${ws_uri}" ]]; then
    if [[ "${detach}" == true ]]; then
      if grep -q "${ready_pattern}" "${log}"; then
        break
      fi
    else
      break
    fi
  fi
  sleep 1
done

if [[ -z "${ws_uri}" ]]; then
  printf '\n[web-showcase] timeout waiting for VM ws URI\n' >&2
  exit 1
fi

printf '\n[web-showcase] WS_URI=%s\n' "${ws_uri}"
printf '[web-showcase] verify: dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart webmcp verify --web-port %s\n' "${web_port}"
printf '[web-showcase] stop: make showcase-stop\n\n'

if [[ "${detach}" == true ]]; then
  exit 0
fi

wait "${fpid}"
