# Oka consumer repin — `3477fb8a` (oka main after #21) (2026-11-09)

| Field | Value |
|-------|--------|
| Pin file | `tool/ci/oka_consumer_pin.txt` |
| SHA (full) | `3477fb8ad96bd96750a7cdbe2959f818e55d6029` |
| Remote verify | `gh api …/oka/commits/main` + `git ls-remote` |
| Source | oka **main** — [#17](https://github.com/Arenukvern/oka/pull/17) Linux L0 ready handshake; [#21](https://github.com/Arenukvern/oka/pull/21) `oka_devices` |
| Prior pin | `754b47500e56c2a9b29d40f83bf23987ac8c0f1d` (see `oka_consumer_repin_754b4750_20261109.md`) |
| Consumer merge | `a2d1e510` — merge `origin/main` (unblocked dirty PR → Actions) |

## Native proof

Completed on consumer **`03c1fdae`**: see `docs/evidence/ndk_3477fb8a_native_green_20261109.md`.

Failed attempt on **`d0fbf497`**: provision `flutter pub get` in fixture (semantics/interface graph) — fixed without weakening native assertions.
