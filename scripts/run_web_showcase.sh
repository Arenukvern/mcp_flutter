#!/usr/bin/env bash
# Run flutter_test_app on Chrome with WebMCP-enabling browser flags.
# Prints VM ws URI when ready. Logs: .showcase/web_app.log
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

bash "${here}/stop_showcase.sh" 2>/dev/null || true
mkdir -p "${showcase_dir}"

printf '[web-showcase] Chrome :%s with WebMCP flags → %s\n' "${web_port}" "${log}"
[[ -n "${flutter_route}" ]] && printf '[web-showcase] route=%s\n' "${flutter_route}"
printf '[web-showcase] recipe: dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart webmcp chrome-args\n\n'

cd "${app_dir}"

# Each flag is a separate --web-browser-flag (Flutter web).
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

flutter run -d chrome \
  --web-port="${web_port}" \
  --host-vmservice-port="${vm_port}" \
  "${route_args[@]}" \
  "${dart_define_args[@]}" \
  --debug \
  --web-browser-flag="--enable-features=WebModelContext" \
  --web-browser-flag="--enable-experimental-web-platform-features" \
  2>&1 | tee "${log}" &
fpid=$!
echo "${fpid}" > "${pid_file}"

ws_uri=""
for _ in $(seq 1 180); do
  ws_uri="$(grep -Eo 'ws://127\.0\.0\.1:[0-9]+/[A-Za-z0-9_=-]+/ws' "${log}" | tail -1 || true)"
  if [[ -n "${ws_uri}" ]]; then break; fi
  sleep 1
done

if [[ -z "${ws_uri}" ]]; then
  printf '\n[web-showcase] timeout waiting for VM ws URI\n' >&2
  exit 1
fi

printf '\n[web-showcase] WS_URI=%s\n' "${ws_uri}"
printf '[web-showcase] verify: dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart webmcp verify --web-port %s\n' "${web_port}"
printf '[web-showcase] stop: make showcase-stop\n\n'

wait "${fpid}"
