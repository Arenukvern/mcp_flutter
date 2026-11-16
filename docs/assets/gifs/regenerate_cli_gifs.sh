#!/usr/bin/env bash
# Regenerate committed CLI/harness GIFs (vhs). Called locally and from CI.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export PATH="${HOME}/.local/bin:${FLUTTER_ROOT:-${HOME}/flutter}/bin:${PATH:-}"
export DISPLAY="${DISPLAY:-:0.0}"
export HARNESS_GIF_DEVICE="${HARNESS_GIF_DEVICE:-chrome}"

cd "$ROOT"
command -v vhs >/dev/null || { echo "vhs not installed" >&2; exit 1; }
command -v flutter-mcp-toolkit >/dev/null || { echo "flutter-mcp-toolkit not on PATH" >&2; exit 1; }

vhs docs/assets/gifs/cli-doctor.tape
vhs docs/assets/gifs/cli-exec.tape
vhs docs/assets/gifs/harness.tape

mkdir -p docs/assets/gifs/frames
for name in cli-doctor cli-exec harness; do
  gif="docs/assets/gifs/${name}.gif"
  ffprobe -v error -show_entries format=duration,size \
    -show_streams -select_streams v:0 \
    -of default=noprint_wrappers=1 "$gif" >"docs/assets/gifs/frames/${name}.ffprobe.txt"
  ffmpeg -y -i "$gif" -vf "select=eq(n\,0)" -vframes 1 \
    "docs/assets/gifs/frames/${name}-frame0.png" 2>/dev/null
  size="$(stat -c%s "$gif")"
  if [ "$size" -gt 5242880 ]; then
    echo "GIF over 5MB cap: $gif ($size bytes)" >&2
    exit 1
  fi
done

echo "regenerate_cli_gifs: OK"