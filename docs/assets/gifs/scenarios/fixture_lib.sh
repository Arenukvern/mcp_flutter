#!/usr/bin/env bash
# Shared headless Chrome bring-up for GIF demo scripts.
set -euo pipefail

MCP_GIF_URI_FILE="${MCP_GIF_URI_FILE:-/tmp/mcp_gif_fixture.uri}"
MCP_GIF_PID_FILE="${MCP_GIF_PID_FILE:-/tmp/mcp_gif_fixture.pid}"
MCP_GIF_LOG="${MCP_GIF_LOG:-/tmp/mcp_gif_fixture.log}"
MCP_GIF_WEB_PORT="${MCP_GIF_WEB_PORT:-9877}"

_gif_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd
}

_gif_ensure_paths() {
  export PATH="${FLUTTER_ROOT:-${HOME}/flutter}/bin:${HOME}/.local/bin:${PATH:-}"
  export DISPLAY="${DISPLAY:-:99}"
}

start_fixture_chrome() {
  _gif_ensure_paths
  local root="$(_gif_repo_root)"
  local app="${root}/showcase/native_layer_capture_fixture"
  if [[ -f "$MCP_GIF_PID_FILE" ]] && kill -0 "$(cat "$MCP_GIF_PID_FILE")" 2>/dev/null; then
    if [[ -f "$MCP_GIF_URI_FILE" ]]; then
      return 0
    fi
  fi
  rm -f "$MCP_GIF_URI_FILE" "$MCP_GIF_PID_FILE"
  : >"$MCP_GIF_LOG"
  (
    cd "$app"
    flutter run -d chrome --web-port="$MCP_GIF_WEB_PORT" \
      --web-browser-flag=--headless=new \
      --web-browser-flag=--disable-gpu
  ) >>"$MCP_GIF_LOG" 2>&1 &
  echo $! >"$MCP_GIF_PID_FILE"
  local uri=""
  for _ in $(seq 1 120); do
    uri="$(grep -Eo 'http://127\.0\.0\.1:[0-9]+/[^ ]+' "$MCP_GIF_LOG" | head -1 || true)"
    if [[ -n "$uri" ]]; then
      echo "$uri" >"$MCP_GIF_URI_FILE"
      sleep 2
      return 0
    fi
    sleep 1
  done
  echo "fixture_lib: VM service URI not found (see $MCP_GIF_LOG)" >&2
  tail -15 "$MCP_GIF_LOG" >&2 || true
  stop_fixture_chrome
  return 1
}

read_fixture_vm_uri() {
  [[ -f "$MCP_GIF_URI_FILE" ]] || return 1
  cat "$MCP_GIF_URI_FILE"
}

fixture_ws_uri() {
  local http
  http="$(read_fixture_vm_uri)"
  echo "ws://${http#http://}/ws"
}

stop_fixture_chrome() {
  if [[ -f "$MCP_GIF_PID_FILE" ]]; then
    local pid
    pid="$(cat "$MCP_GIF_PID_FILE")"
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$MCP_GIF_PID_FILE"
  fi
  pkill -f "flutter run.*native_layer_capture_fixture" 2>/dev/null || true
  rm -f "$MCP_GIF_URI_FILE"
}