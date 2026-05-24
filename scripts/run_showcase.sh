#!/usr/bin/env bash
# Run the flutter_test_app showcase on macOS and print the canonical VM
# websocket URI once the app is reachable. The app is left running in the
# foreground so `flutter r` / `R` / `q` still work interactively.
#
# Typical agent use:
#   make showcase-stop          # end stray instances first
#   make showcase               # in one terminal
#   flutter-mcp-toolkit exec --name semantic_snapshot \
#     --args '{"connection":{"targetId":"<uri from this script>"}}'
#
# The showcase includes a Capture section with a real AppKitView (macOS).
# For desktop_window screenshots / validate-runtime, grant Screen Recording
# to the terminal or IDE running flutter-mcp-toolkit on this Mac.

set -u
set -o pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/.." && pwd)"
app_dir="${repo_root}/flutter_test_app"
showcase_dir="${repo_root}/.showcase"
pid_file="${showcase_dir}/flutter.pid"
app_log="${showcase_dir}/flutter_app.log"

stop_running_showcase() {
  bash "${here}/stop_showcase.sh"
}

trap 'stop_running_showcase; printf "\n[showcase] log retained at %s\n" "${app_log}"' EXIT INT TERM

mkdir -p "${showcase_dir}"
stop_running_showcase

printf "[showcase] running flutter test app on macOS…\n"
printf "[showcase] logs → %s\n\n" "${app_log}"

cd "${app_dir}"

# Log to file; stream to terminal for interactive use.
flutter run -d macos --debug 2>&1 | tee "${app_log}" &
flutter_pid=$!
echo "${flutter_pid}" > "${pid_file}"

printf "[showcase] flutter pid %s (also in %s)\n" "${flutter_pid}" "${pid_file}"

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
printf "  flutter-mcp-toolkit exec --name semantic_snapshot \\\\\n"
printf "    --args \"{\\\"connection\\\":{\\\"targetId\\\":\\\"\$WS\\\"}}\"\n"
printf "\n"
printf "[showcase] app is running. Press r for hot reload, q to quit.\n"
printf "[showcase] to stop from another terminal: make showcase-stop\n\n"

wait "${flutter_pid}"
