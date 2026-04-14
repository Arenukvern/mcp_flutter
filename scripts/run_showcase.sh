#!/usr/bin/env bash
# Run the flutter_test_app showcase on macOS and print the canonical VM
# websocket URI once the app is reachable. The app is left running in the
# foreground so `flutter r` / `R` / `q` still work interactively.
#
# Typical agent use:
#   make showcase                 # in one terminal
#   flutter_mcp_cli exec --name semantic_snapshot \
#     --args '{"connection":{"targetId":"<uri from this script>"}}'

set -u
set -o pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/.." && pwd)"
app_dir="${repo_root}/flutter_test_app"

log_dir="$(mktemp -d -t flutter_showcase.XXXXXX)"
app_log="${log_dir}/flutter_app.log"
trap 'printf "\n[showcase] log retained at %s\n" "${app_log}"' EXIT

printf "[showcase] running flutter test app on macOS…\n"
printf "[showcase] logs → %s\n\n" "${app_log}"

cd "${app_dir}"

# Kick off the app in the background so we can poll the log for readiness.
flutter run -d macos --debug 2>&1 | tee "${app_log}" &
flutter_pid=$!

# Clean up the flutter process if this script is interrupted.
trap 'kill ${flutter_pid} 2>/dev/null || true; printf "\n[showcase] stopped (pid %s)\n" "${flutter_pid}"' INT TERM

# Wait up to 180s for the VM service endpoint to appear in the log.
vm_uri=""
for _ in $(seq 1 180); do
  vm_uri="$(grep -Eo 'http://127\.0\.0\.1:[0-9]+/[A-Za-z0-9_=-]+/' "${app_log}" | tail -1)"
  if [ -n "${vm_uri}" ]; then break; fi
  sleep 1
done

if [ -z "${vm_uri}" ]; then
  printf "\n[showcase] gave up waiting for Dart VM Service URI (180s).\n" >&2
  wait "${flutter_pid}" 2>/dev/null || true
  exit 1
fi

# Convert http://host:port/token/ → ws://host:port/token/ws
ws_uri="${vm_uri/http:/ws:}ws"

printf "\n"
printf "[showcase] Dart VM Service:  %s\n" "${vm_uri}"
printf "[showcase] canonical WS URI: %s\n" "${ws_uri}"
printf "\n"
printf "  export WS='%s'\n" "${ws_uri}"
printf "  flutter_mcp_cli exec --name semantic_snapshot \\\\\n"
printf "    --args \"{\\\"connection\\\":{\\\"targetId\\\":\\\"\$WS\\\"}}\"\n"
printf "\n"
printf "[showcase] app is running. Press r for hot reload, q to quit.\n\n"

wait "${flutter_pid}"
