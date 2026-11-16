#!/usr/bin/env bash
# Full exec demo (warm + display) for local smoke tests.
set -euo pipefail
dir="$(dirname "$0")"
bash "$dir/warm_fixture.sh"
bash "$dir/exec_demo_display.sh"