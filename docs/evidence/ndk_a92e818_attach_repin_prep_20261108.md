# Coherent repin prep: oka `a92e818a…` (attach argv revision)

**Target SDK SHA:** `a92e818a18889cd70ef3078031bfaf249a92d728` (supersedes fixture `30ef847…`)  
**Consumer pin file:** updated locally; **not pushed** until SHA is fetchable from `oka` remote and local member gates pass.

## SDK change (evidence-only candidate until native proves)

- Remove `--debug-url` direct short-circuit path.
- Use `--device-vmservice-port` (device port from logcat, e.g. **33027**) + `--host-vmservice-port` (recorded SDK adb-forward local, e.g. **35745**).
- Log discovery; on failure write `.flutter_mcp/attach-handshake-failure.json` (actual argv, events, stderr ring, VM context).

**Prior classification:** `1b7f18f` attach failure likely tied to `--debug-url` + host-port pairing (`attach_argv_9e6_vs_1b7.json` in AgentStore).

## Consumer (this branch)

- Stop receipt: **SDK `DevSessionStopReport.sessionCleanup` getters only** (no file-parser identity).
- On native **launch/attach** failure: bundle includes `attachHandshakeFailure` + `android_attach_handshake_failure.json` when SDK sidecar exists; `rawSessionTeardownFile` attach-only via `readSessionTeardownFile`.
- **No** timeout bump, blind native retry, or consumer port workarounds.

## Gate status

| Step | Status |
|------|--------|
| `git fetch` oka `a92e818a…` | **blocked** — ref not on remote at prep time |
| harness / SDK local gates | pending SHA checkout |
| purposeful native push | hold until repin + gates green |

**No merge/publish.**
