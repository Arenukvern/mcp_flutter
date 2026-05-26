# Android OEM notes (AgentKit shortcuts)

`AndroidShortcutsXmlEmitter` produces a single `res/xml/agentkit_shortcuts.xml` for stock Android, **Xiaomi HyperOS**, and **Huawei** APK builds. No separate emitter is required.

## HyperOS / MIUI

- Ensure the app is allowed to run in the background if shortcuts open via deep link when the process was killed.
- Users may need to disable battery restrictions for reliable `agentkit://invoke/...` delivery.

## Huawei (GMS-less APK)

- Same `shortcuts.xml` and manifest `android.app.shortcuts` meta-data as stock Android.
- App Actions / Google Assistant integration is unavailable without GMS; shortcuts still work from the launcher and in-app surfaces that read dynamic shortcuts.

## Gradle sync

Inject the `kAndroidGradleCodegenHook` template from `agentkit_platform` into `android/app/build.gradle.kts` once so `preBuild` runs:

```bash
flutter-mcp-toolkit codegen sync --platform android
```
