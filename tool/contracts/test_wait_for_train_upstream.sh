#!/usr/bin/env bash
# Contract test for tool/release/wait_for_train_upstream.sh.
#
# Serves a local pub.dev API fixture (python http.server, in-memory) and
# exercises:
#   - no same-train floors -> immediate pass (offline)
#   - upstream floor appears after a few polls -> pass (the race this fixes)
#   - upstream floor never appears -> nonzero exit within the timeout
#   - constraint parsing: caret floors from `dependencies:` only (dev/
#     unconstrained/external deps ignored)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WAITER="$ROOT_DIR/tool/release/wait_for_train_upstream.sh"

fail() { echo "test_wait_for_train_upstream: $*" >&2; exit 1; }
ok() { echo "test_wait_for_train_upstream: $*"; }

[[ -f "$WAITER" ]] || fail "missing $WAITER"
command -v python3 >/dev/null 2>&1 || fail "python3 required"

tmpdir="$(mktemp -d)"
server_pid=""
cleanup() {
  [[ -n "$server_pid" ]] && kill "$server_pid" 2>/dev/null
  rm -rf "$tmpdir"
}
trap cleanup EXIT

free_port() {
  python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'
}

wait_for_server() {
  local port="$1"
  for _ in $(seq 1 25); do
    if curl -fsSL "http://127.0.0.1:${port}/api/packages/flutter_mcp_toolkit_core" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  return 1
}

# --- Case 0: no same-train floors -> immediate pass (offline, no server).
cat >"$tmpdir/no_deps.yaml" <<'YAML'
name: flutter_mcp_toolkit_server
version: 8.0.0
dependencies:
  args: ^2.4.0
YAML
bash "$WAITER" \
  --tag flutter_mcp_toolkit_server-v8.0.0 \
  --pubspec "$tmpdir/no_deps.yaml" \
  --pub-api-base "http://127.0.0.1:1/api" \
  --timeout-seconds 3 >/dev/null 2>&1 &&
  ok "no same-train floors passes without network" ||
  fail "no-floor case must pass immediately"

# --- Fixture server: /api/packages/flutter_mcp_toolkit_core exposes 8.0.0
# only from the 3rd poll on (the concurrent-dispatch race this waiter fixes).
cat >"$tmpdir/serve.py" <<'PY'
import http.server
import json
import sys

port = int(sys.argv[1])
count = {"core": 0}


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/api/packages/flutter_mcp_toolkit_core":
            count["core"] += 1
            versions = [{"version": "7.2.2"}]
            if count["core"] >= 3:
                versions.append({"version": "8.0.0"})
            body = json.dumps(
                {"name": "flutter_mcp_toolkit_core", "versions": versions}
            ).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *args):
        pass


http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY

# --- Constraint parsing fixture: the kernel's real dependency shape.
# Only `flutter_mcp_toolkit_core ^8.0.0` from `dependencies:` must be waited
# on; the dev_dependencies floor (^7.0.0) and external deps are ignored.
cat >"$tmpdir/kernel_deps.yaml" <<'YAML'
name: flutter_mcp_toolkit_capability_kernel
version: 8.0.0
environment:
  sdk: ^3.5.0
dependencies:
  flutter:
    sdk: flutter
  flutter_mcp_toolkit_core: ^8.0.0
  intentcall_session: ^1.3.1
  from_json_to_json: ^0.6.0
dev_dependencies:
  flutter_mcp_toolkit_core: ^7.0.0
  lints: ^4.0.0
YAML

port="$(free_port)"
python3 "$tmpdir/serve.py" "$port" &
server_pid=$!
wait_for_server "$port" || fail "fixture server did not come up"

POLL_SECONDS=1 bash "$WAITER" \
  --tag flutter_mcp_toolkit_capability_kernel-v8.0.0 \
  --pubspec "$tmpdir/kernel_deps.yaml" \
  --pub-api-base "http://127.0.0.1:${port}/api" \
  --timeout-seconds 60 >/dev/null 2>&1 &&
  ok "waits for a late-exposed upstream floor then passes" ||
  fail "late-exposed floor case must pass"

kill "$server_pid" 2>/dev/null
server_pid=""

# --- Case 2: never-exposed floor -> must fail within the timeout.
port="$(free_port)"
python3 - "$port" <<'PY' &
import http.server
import json
import sys

port = int(sys.argv[1])
body = json.dumps(
    {"name": "flutter_mcp_toolkit_core", "versions": [{"version": "1.0.0"}]}
).encode()


class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/api/packages/flutter_mcp_toolkit_core":
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *args):
        pass


http.server.ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
PY
server_pid=$!
wait_for_server "$port" || fail "fixture server did not come up"

cat >"$tmpdir/pubspec_never.yaml" <<'YAML'
name: flutter_mcp_toolkit_capability_kernel
version: 8.0.0
dependencies:
  flutter_mcp_toolkit_core: ^8.0.0
YAML
if POLL_SECONDS=1 bash "$WAITER" \
  --tag flutter_mcp_toolkit_capability_kernel-v8.0.0 \
  --pubspec "$tmpdir/pubspec_never.yaml" \
  --pub-api-base "http://127.0.0.1:${port}/api" \
  --timeout-seconds 3 >/dev/null 2>&1; then
  fail "never-exposed floor must fail within the timeout"
else
  ok "never-exposed floor fails within the timeout"
fi

ok "wait_for_train_upstream contracts OK"
