# Universal automation dependency pinning

`universal_automation_semantics` **0.4.x / 0.5.x** on pub.dev requires
`universal_automation_interface` **^0.4.0**, but pub.dev’s latest published
interface is **0.3.0** — so hosted-only resolution cannot satisfy the
observation-render stack until **interface 0.4.0 is published** on pub.dev
(this repo cannot publish that package).

**Bounded in-repo fix:** the workspace root `pubspec.yaml` declares
`dependency_overrides` for **git** UA packages at the immutable ref in
`tool/ci/universal_automation_ref.txt`
(`1c6f7982a1764ea090860d23aff284c5df073159`). `dart pub get` clones that
commit; no gitignored `universal_automation/` checkout is required for CI.

**Pub publish note:** `mcp_toolkit` pub.dev releases remain blocked on the same
upstream publish until interface 0.4.0 is on pub.dev (documented blocker).
