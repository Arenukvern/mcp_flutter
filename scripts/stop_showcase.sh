#!/usr/bin/env bash
# Stop stray flutter_test_app / showcase processes and free the default VM port.
# Safe to run repeatedly (no-op when nothing is running).
#
# Usage:
#   make showcase-stop
#   bash scripts/stop_showcase.sh

set +e

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/.." && pwd)"
pid_file="${repo_root}/.showcase/flutter.pid"

printf "[stop_showcase] cleaning flutter_test_app / MCP showcase processes…\n"

if [ -f "${pid_file}" ]; then
  saved_pid="$(cat "${pid_file}" 2>/dev/null)"
  if [ -n "${saved_pid}" ]; then
    kill -TERM "${saved_pid}" 2>/dev/null || true
    sleep 0.5
    kill -KILL "${saved_pid}" 2>/dev/null || true
  fi
  rm -f "${pid_file}"
fi

# Flutter tool driving this repo's test app.
pkill -f "flutter run.*flutter_test_app" 2>/dev/null || true
pkill -f "flutter_tools.*run.*macos" 2>/dev/null || true

# macOS showcase GUI (survives parent flutter kill).
if [ "$(uname -s)" = "Darwin" ]; then
  killall test_app 2>/dev/null || true
fi

# Default integration / showcase VM port.
if command -v lsof >/dev/null 2>&1; then
  lsof -ti :8181 2>/dev/null | while read -r pid; do
    kill -TERM "${pid}" 2>/dev/null || true
  done
  sleep 0.3
  lsof -ti :8181 2>/dev/null | xargs kill -9 2>/dev/null || true
fi

# MCP server binaries spawned by integration tests.
pkill -f flutter-mcp-toolkit-server 2>/dev/null || true
pkill -f flutter_mcp_toolkit_server 2>/dev/null || true

printf "[stop_showcase] done\n"
