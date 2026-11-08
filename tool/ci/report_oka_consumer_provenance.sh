#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
pin="$(tr -d '[:space:]' < "$repo_root/tool/ci/oka_consumer_pin.txt")"
oka="$repo_root/oka"
out="${1:-$repo_root/.native_capture/oka_consumer_provenance.json}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "oka consumer provenance: $*" >&2
  exit 1
}

[[ -d "$oka/.git" ]] || fail "oka checkout missing (run provision_oka_consumer_test_pin.sh)"

resolved="$(git -C "$oka" rev-parse HEAD)"
[[ "$resolved" == "$pin" || "$resolved" == "${pin:0:40}" ]] || fail "checkout HEAD $resolved != pin $pin"

oka_cli="$(command -v oka || true)"
[[ -n "$oka_cli" ]] || fail "OKA_BIN not on PATH after path activation"

oka_version="$(oka --version 2>&1)" || fail "oka --version failed"

(cd "$repo_root" && flutter pub get >/dev/null)
(cd "$repo_root/showcase/native_layer_capture_fixture" && flutter pub get >/dev/null)

(cd "$repo_root/packages/harness" && dart pub deps --style=compact >"$tmp/harness_deps.txt")
(cd "$repo_root/showcase/native_layer_capture_fixture" && dart pub deps --style=compact >"$tmp/fixture_deps.txt")

export REPORT_PIN="$pin"
export REPORT_HEAD="$resolved"
export REPORT_CLI="$oka_cli"
export REPORT_VER="$oka_version"
export REPORT_OUT="$out"
export REPORT_HARNESS="$tmp/harness_deps.txt"
export REPORT_FIXTURE="$tmp/fixture_deps.txt"
export REPORT_REPO="$repo_root"

python3 - <<'PY'
import json, os, pathlib, urllib.parse

repo = pathlib.Path(os.environ["REPORT_REPO"])
pin = os.environ["REPORT_PIN"]
head = os.environ["REPORT_HEAD"]
oka_root = (repo / "oka/packages").resolve()

def load_deps(path: str) -> str:
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()

def package_config_roots(pkg_dir: pathlib.Path, repo: pathlib.Path) -> dict[str, str]:
    pc = pkg_dir / ".dart_tool" / "package_config.json"
    if not pc.exists():
        pc = repo / ".dart_tool" / "package_config.json"
    if not pc.exists():
        raise SystemExit(f"missing package_config for {pkg_dir} (tried package and workspace root)")
    data = json.loads(pc.read_text(encoding="utf-8"))
    out = {}
    pc_dir = pc.parent
    for entry in data.get("packages", []):
        name = entry.get("name", "")
        root = entry.get("rootUri", "")
        if not name.startswith("oka") and name != "resource_composition":
            continue
        if root.startswith("file:"):
            path = pathlib.Path(urllib.parse.unquote(urllib.parse.urlparse(root).path)).resolve()
        elif root.startswith("../") or root.startswith("..\\"):
            path = (pc_dir / root).resolve()
        else:
            raise SystemExit(f"{name}: unsupported rootUri {root!r}")
        out[name] = str(path)
        if oka_root not in path.parents and path != oka_root:
            raise SystemExit(f"{name} resolves outside pinned oka checkout: {path}")
    return out

harness_roots = package_config_roots(repo / "packages/harness", repo)
fixture_roots = package_config_roots(repo / "showcase/native_layer_capture_fixture", repo)
required = {"oka_core", "oka_android", "oka_harness", "resource_composition"}
missing_h = required - set(harness_roots)
missing_f = {"oka_core", "oka_android"} - set(fixture_roots)
if missing_h:
    raise SystemExit(f"harness missing pinned oka packages: {sorted(missing_h)}")
if missing_f:
    raise SystemExit(f"fixture missing pinned oka packages: {sorted(missing_f)}")

harness_deps = load_deps(os.environ["REPORT_HARNESS"])[:12000]
fixture_deps = load_deps(os.environ["REPORT_FIXTURE"])[:12000]
if "dependency overrides" not in harness_deps:
    raise SystemExit("harness pub deps missing dependency overrides (path pin not applied)")
if "dependency overrides" not in fixture_deps:
    raise SystemExit("fixture pub deps missing dependency overrides (path pin not applied)")

data = {
    "pinSource": "tool/ci/oka_consumer_pin.txt",
    "pinFile": pin,
    "okaCheckoutHead": head,
    "pinMatchesHead": head == pin,
    "okaCliPath": os.environ["REPORT_CLI"],
    "okaCliVersionStdout": os.environ["REPORT_VER"].strip(),
    "cliActivation": "dart pub global activate --source path oka/packages/oka",
    "harnessOkaPackageRoots": harness_roots,
    "fixtureOkaPackageRoots": fixture_roots,
    "harnessPubDepsCompact": harness_deps,
    "fixturePubDepsCompact": fixture_deps,
    "note": "Provisional unmerged oka PR #18 test pin only; not production cutover or hosted release.",
}
os.makedirs(os.path.dirname(os.environ["REPORT_OUT"]) or ".", exist_ok=True)
with open(os.environ["REPORT_OUT"], "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
print("wrote", os.environ["REPORT_OUT"])
PY
