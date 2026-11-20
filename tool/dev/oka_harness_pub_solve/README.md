# oka_harness

Device E2E targets over oka's owning dev sessions (ADR-0026): launch an
Android app via `oka dev`, pick the forwarded VM service URI up from the
runner-session contract, and drive/assert it with the
[flutter_mcp_harness](https://pub.dev/packages/flutter_mcp_harness)
scenario core.

## Why

oka owns compile/sync and process lifecycle; the MCP toolkit is the
observation oracle (ADR-0024). Test flows used to bridge the two with shell
(`oka build` → `adb install` → `am start` → grep). This package makes the
`launch/connect` segment of ADR-0024's shape a reusable target instead:

```text
provision/install → launch/connect → observe → assert → report → teardown
        oka dev ▸ ▸ AndroidAppTarget      WidgetDriver ▸ Scenario ▸ stop()
```

Contract notes:

- `oka dev` is the **single owning attach session**. The target never opens
  a second attach (which would kill the owner) and never scrapes logcat for
  the VM URI — it reads `.flutter_mcp/runner-session.json` (spec v2, see
  mcp_flutter ADR-0014), whose absence is the liveness signal.
- App logs stream in from `adb logcat` (prefixed `[logcat] `) into the same
  `LogTap`, so log assertions read the same as desktop targets.
- `launch(build: false)` deliberately refuses: bring-up through a second
  owner is exactly the bug class ADR-0014 removed. To observe an
  already-running session use `driverForLiveSession(projectDir)`.

## Usage

```dart
final app = await AndroidAppTarget(
  projectDir: '.',
  deviceId: 'emulator-5554', // pin on multi-device hosts
).launch();

final driver = WidgetDriver(await app.vm());
final ref = await driver.findRef('start');
await driver.tap(ref!);

await app.stop(); // tears down the owning session
```

See `example/emulator_smoke.dart` for a runnable composition root.

## Verify (offline — no device needed)

```sh
dart test
```

The tests run a fake `oka` script that publishes a valid runner-session
file, exercising launch → attach → stop and the timeout/teardown path.
