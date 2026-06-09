#!/usr/bin/env bash
set -euo pipefail

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"

cat >"$fake_bin/steward" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 ${2:-}" == "doctor --json" ]]; then
  printf '{"config":{"valid":true}}\n'
  exit 0
fi
printf 'ran %s\n' "$*"
SH
chmod +x "$fake_bin/steward"

output="$(PATH="$fake_bin:$PATH" bash tool/steward/run.sh actions list --json)"
if [[ "$output" != "ran actions list --json" ]]; then
  echo "expected wrapper to use valid PATH steward, got: $output" >&2
  exit 1
fi

cat >"$fake_bin/steward" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 ${2:-}" == "doctor --json" ]]; then
  echo "unknown command doctor" >&2
  exit 64
fi
printf 'stale %s\n' "$*"
SH
chmod +x "$fake_bin/steward"

if PATH="$fake_bin:$PATH" bash tool/steward/run.sh actions list --json >"$tmp_dir/out" 2>"$tmp_dir/err"; then
  echo "expected stale steward to fail without SKILL_STEWARD_ROOT" >&2
  exit 1
fi

grep -q "Install Skill Steward CLI" "$tmp_dir/err" || {
  echo "expected install guidance for stale steward" >&2
  cat "$tmp_dir/err" >&2
  exit 1
}

skill_steward_root="$tmp_dir/skill_steward"
mkdir -p "$skill_steward_root/packages/steward_cli/bin"
touch "$skill_steward_root/packages/steward_cli/pubspec.yaml"
touch "$skill_steward_root/packages/steward_cli/bin/steward.dart"

cat >"$fake_bin/dart" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2" == "pub get" ]]; then
  exit 0
fi
if [[ "$1" == --packages=* && "$2" == */bin/steward.dart ]]; then
  shift 2
  if [[ "$1 ${2:-}" == "doctor --json" ]]; then
    printf '{"config":{"valid":true}}\n'
    exit 0
  fi
  printf 'source-run %s\n' "$*"
  exit 0
fi
echo "unexpected dart invocation: $*" >&2
exit 1
SH
chmod +x "$fake_bin/dart"

output="$(
  PATH="$fake_bin:$PATH" \
  SKILL_STEWARD_ROOT="$skill_steward_root" \
  bash tool/steward/run.sh actions list --json
)"
if [[ "$output" != "source-run actions list --json" ]]; then
  echo "expected wrapper to use source-run Steward fallback, got: $output" >&2
  exit 1
fi

echo "OK: tool/steward/run.sh validates Steward command surface"
