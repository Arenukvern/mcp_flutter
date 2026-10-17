# ADR 0018: The web tier — WebBuildTarget, FlutterWebCdp, and the scenario evidence bundle

- Status: Accepted
- Date: 2026-10-02
- Builds on: ADR-0015 (harness lifecycle), ADR-0017 (invoke tier);
  browser-side primitives per universal-automation-family ADR-0045
  (live-DOM name location, focus restoration, JIT/AOT tier matrix)

## Context

The harness's web story was "bring your own everything": serve the
bundle, launch Chrome, and rediscover by hand the measured failure
classes — MIME-as-text rendering, zombie-Chrome adoption on fixed CDP
ports, swallowed first clicks, toggles re-clicking themselves off,
key events no-oping without OS focus, reloads destroying in-memory app
state. Each multiplayer-gate session re-rolled ~200 lines of plumbing
and re-lost the same hours. Separately, a failed step exposed only its
error string: one run was undiagnosable until a hand-rolled console
capture named the app-side exception (a DropdownButton assert rendered
as a canvas error screen, invisible in the DOM).

## Decision

Three additions to `flutter_mcp_harness`:

1. **`WebBuildTarget`** — build web (skippable; the caller owns
   freshness) → `StaticWebServer` (correct MIME — a wrong type renders
   HTML as text — index fallback, free-port by default) →
   `ChromeAppTarget` (anti-backgrounding flags, headed by default:
   headless never runs rAF and Flutter freezes) → `CdpDriver`. Fixed
   CDP ports are opt-in, not default: a fixed port adopts a zombie
   Chrome from a crashed run (measured).
2. **`FlutterWebCdp`** — the measured interaction techniques over a
   page: locate-by-name in the live `flt-semantics` DOM with
   effect-verified clicks (`clickText(expect:)` — effect checked BEFORE
   re-clicking, because a toggle re-click flips itself off), stable-rect
   reads (animation mid-flight clicks whatever scrolls under the
   coordinates), `warmUpClick` (the first click after load is
   swallowed), caret typing (`bringToFront` + `insertText`),
   `popRoute` (in-app only — reloads drop memory state),
   `dumpAx` evidence.
3. **`EvidenceCollector` + `Scenario(evidence:)`** — console +
   exception capture from any attached CDP page, app log taps, and
   lazily-produced files (AX dumps), dumped under `$TMPDIR/<scenario>/`
   on the first failing step. Best-effort by contract: evidence must
   never mask the failure.

The tier split this encodes: **JIT web/desktop = the toolkit tier
(WidgetDriver, native refs); AOT web = the CDP tier (WebBuildTarget +
FlutterWebCdp); AOT desktop = the OS synthesis tier (family
ADR-0040)**. `flutter run -d chrome` + DWDS remains the DO-NOT-USE path
for gates: sustained VM-service polling killed DDC compilers twice.

## Consequences

- Consumers stop re-rolling serving/port/MIME/retry plumbing; the
  gate's `_CdpPeer` shrinks to scenario logic.
- Failures carry their own diagnosis (console + AX + logs in one
  directory).
- The toolkit (JIT tier) and this (web/AOT tier) stay two faces of the
  same driver contract; app-side `window.__mcpActions` publication is
  the tracked bridge that brings typed intents to AOT web.
