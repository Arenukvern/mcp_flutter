# Binary release contract (product harness)

Normative pattern for repos whose **primary consumer artifact is an executable** (CLI, MCP server binary).

Meta repos that ship **only** `SKILL.md` + docs (Skill Steward) use `npx skills` — see [ADR 0010](../../../docs/decisions/0010-binary-releases-for-product-harness-not-meta-steward.mdx).

## When to use binaries vs other surfaces

| Primary artifact | Ship | Do not force |
|------------------|------|----------------|
| MCP/CLI server | GitHub Release tarballs + checksums + `install.sh` | Full git clone for end users |
| Product library | Package manager registries (e.g. pub, npm, crates.io) | Duplicate server binary in library package |
| Agent skills | `npx skills add owner/repo` | Tarball of entire monorepo for skill-only consumers |
| Meta validate CLI tied to repo tree | CI + maintainer clone | Global binary without repo ([ADR 0010](../../../docs/decisions/0010-binary-releases-for-product-harness-not-meta-steward.mdx)) |

## Release legibility + binaries (both required)

Binary trains still obey the **release legibility contract** from `SKILL.md`:

1. Version/changelog in git (release-please, Changesets, or `CHANGELOG.md`).
2. Tag `vX.Y.Z` is the publish event.
3. CI attaches **artifacts that match** the tagged version (no “latest main” ambiguity).
4. `install.sh` (or equivalent) defaults to **same version** as plugin manifest / expected server version when applicable.

## Minimal layout (AOT example)

```text
tool/release/build_release_artifacts.sh   # compile executable per triple
dist/release/*.tar.gz                     # bin/* + LICENSE
dist/release/checksums.txt              # sha256 of tarballs
install.sh                                # curl-friendly; no clone
.github/workflows/release.yml             # on push tag v*
```

**CI matrix (typical):** `darwin-arm64`, `linux-x64` — add triples only when you will test them.

**Consumer:**

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/install.sh | bash
# pinned:
curl -fsSL .../install.sh | bash -s -- --version vX.Y.Z
```

## Binary Distribution Blueprint & Design Patterns

### 1. Zero-Dependency AOT Compilation
* **Pattern:** Compile executables directly to native platform machine code (e.g., `dart compile exe` for Dart, `go build` for Go, `cargo build --release` for Rust).
* **Benefit:** Decouples execution from the local SDK, allowing the CLI/MCP server to run on vanilla environments with no pre-installed runtimes.

### 2. Monorepo Path Override Resolution
* **Pattern:** For CLI tools that share internal workspace packages (via workspace package paths or local overrides), compile them in an isolated workspace where path references are resolved statically at build time.
* **Benefit:** Bypasses public registry restrictions (which block publishing packages with local path overrides) and compiles all necessary modules into a single, redistributable binary.

### 3. Curl-Friendly `install.sh` Mechanics
A secure and robust `install.sh` must include the following logic:
* **Platform/Architecture Detection:** Use `uname -s` and `uname -m` to determine OS and CPU arch, and fail gracefully if not supported.
* **From-Source Compilation Fallback:** If run within a local git clone (or source directory) and compiler toolchains are available (e.g. Dart, Cargo, Go, C/C++), compile the binary locally instead of fetching from GitHub. This supports local developer versions and provides a path for host architectures without published precompiled releases.
* **Resilient Version Resolution:** Do not rely exclusively on GitHub `/releases/latest` API (which is prone to rate-limiting and returns 404 if no release exists yet). Fallback to reading the version from the raw repository source manifest on the primary branch (e.g. `pubspec.yaml`, `package.json`, or `VERSION` file) or local manifests.
* **Client-Resilient Fallbacks:** Both download operations and API/manifest lookups must support multiple tools (e.g., both `curl` and `wget`) gracefully.
* **Diagnostic Error Interception:** Gracefully catch HTTP download and verification failures (such as 404 for unreleased tags) and output helpful, actionable diagnostics (recommending local compilation or cloning).
* **SHA-256 Integrity Verification:** Prior to unpacking, fetch the `checksums.txt` file and verify the SHA-256 hash using `shasum -a 256` or `sha256sum`.
* **Profile-Safeguarded PATH Configuration:** Detect the active shell environment (Zsh/Bash) and check if the installation directory is already literally configured in the profile using `grep -F -q`. Only append the export statement if not already configured, preventing duplicate environment entries and profile file bloat.
* **Self-Validating Smoke Test:** Execute the compiled tool with `--help` at the end of the installation to confirm viability.

### 4. Configuration Auto-Wiring
* **Pattern:** Build an `init` or `setup` subcommand inside the CLI itself (e.g., `[cli-name] init <agent>`).
* **Benefit:** Automatically writes the correct MCP configuration (like JSON-RPC configs) to the agent's global workspace directories (e.g., `~/Library/Application Support/` or `.claude`), avoiding manual setup errors.

## Version single source of truth

Pick one SSOT; sync everything else in the release PR:

| SSOT style | Examples |
|------------|----------|
| Root `VERSION` file | Product version manifest |
| `packageManager` + release-please manifest | JS monorepos |
| `pubspec.yaml` + Melos | Dart monorepos |

**Gate:** CI script fails if plugin manifest, embedded runtime version, and release asset names disagree.

### Polyglot Tooling and Version Synchronization
* **Language Parity:** If the repository uses a Node-based version manager (such as Changesets) but the CLI or executable product is built in another language (e.g. Dart, Rust, Go), write any version-synchronization or packaging scripts in the product's primary language (e.g. `.dart` or `.rs` scripts) rather than Node/JavaScript.
* **Why:** This maintains toolchain uniformity, type safety, and avoids introducing alien runtime dependencies (like Node/npm packages) inside compiler-specific package directories. Run them via the package manager scripts (e.g. `"changeset:version": "changeset version && dart run tool/sync_versions.dart"`).

### GitHub Actions Trigger Limitations (GITHUB_TOKEN vs. PAT)
* **Problem:** When a release workflow (such as `changesets/action` or a version bump commit step) pushes a Git tag using the default GitHub `GITHUB_TOKEN` credentials, GitHub will **not** trigger subsequent workflows (like a binary compilation workflow) configured to run on tag push (`on: push: tags`). This is a security feature to prevent recursive actions.
* **Solutions:**
  1. **Configure a PAT/App Token:** Authenticate the checkout and release steps in the tagging workflow using a Personal Access Token (PAT) or GitHub App installation token. Pushes made using custom tokens will correctly trigger tag-based workflows.
  2. **Trigger on Workflow Run:** Alternatively, configure the binary release workflow to trigger upon the successful completion of the release/tagging workflow using `on: workflow_run`.
  3. **Provide Manual Fallbacks:** Support a manual trigger (`on: workflow_dispatch`) or a manual tag re-push step (deleting and pushing the tag from a developer machine) to trigger compilation if automatic triggers fail.

## MoE — is “don’t clone” always best?

| Lens | Verdict |
|------|---------|
| **End user of MCP server** | Yes — binaries + install.sh reduce friction and support tickets. |
| **Skill-only consumer** | No — `npx skills` already avoids clone; binaries add nothing. |
| **Maintainer / contributor** | Clone remains correct; dogfood from source. |
| **Security** | Prefer checksums + pinned `--version`; document supply-chain in SECURITY.md. |
| **Small meta repo** | Binary matrix cost > benefit until CLI is useful without repo tree. |

## Anti-patterns

| Anti-pattern | Why |
|--------------|-----|
| “Download repo zip” as install docs for a server product | Slow, wrong branch, no checksums |
| Binaries on Releases without changelog in git | Agents cannot read “what shipped” |
| Second version source (hand bump + bot) | install.sh fetches wrong tarball |
| Shipping skills only as release assets | Breaks `npx skills` discovery |
| Changesets on a binary-only Rust CLI with no JS packages | Wrong generator — use release-plz / git-cliff |

## Adoption checklist (product harness)

- [ ] `build_release_artifacts.sh` (or Makefile `release-artifacts`) documented in DX_FAQ
- [ ] `install.sh` supports `--version`, env override, checksum verify
- [ ] Workflow on `v*` tag uploads tarballs + `checksums.txt`
- [ ] Plugin / MCP config docs point to **binary path**, not `git clone && make`
- [ ] Maintainer checklist includes binary attach step (archetype A maintainer checklist)

## Sibling map

| Repo Type | Distribution face |
|------|-------------------|
| **Product MCP** | Release binaries + `npx skills` for skills |
| **Platform Libs** | Package manager registries (pub, npm, crates.io, etc.) |
| **Meta Steward** | `npx skills` only; no binary train |
| **CLI Harness** | CLI from source (or packaged binaries when shipping standalone executable) |
