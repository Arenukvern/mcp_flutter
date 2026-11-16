#!/usr/bin/env bash
# Full doctor demo (warm + display) for local smoke tests.
set -euo pipefail
dir="$(dirname "$0")"
bash "$dir/warm_fixture.sh"
bash "$dir/doctor_demo_display.sh"