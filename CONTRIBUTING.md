# Contributing

We welcome pull requests and issues on [GitHub](https://github.com/Arenukvern/mcp_flutter).

**Full guide (setup, commits, releases, PR checklist):** [docs/contributing/contribution_guide.mdx](docs/contributing/contribution_guide.mdx) · [docs.page](https://docs.page/Arenukvern/mcp_flutter/contributing/contribution_guide)

## Maintainers

### Release legibility (cross-repo contract)

Product harness releases should keep **changelog in git** and **binaries aligned with the tag**. The normative pattern lives in Skill Steward:

- Skill: [`release-changelog-harness`](https://github.com/Arenukvern/skill_steward/tree/main/skills/release-changelog-harness) — install: `npx skills add arenukvern/skill_steward --skill release-changelog-harness`
- Reference: [binary-release-contract.md](https://github.com/Arenukvern/skill_steward/blob/main/skills/release-changelog-harness/references/binary-release-contract.md)
- ADR (meta vs product): [ADR 0010 — binary releases for product harness](https://github.com/Arenukvern/skill_steward/blob/main/docs/decisions/0010-binary-releases-for-product-harness-not-meta-steward.md)

mcp_flutter is the reference implementation: release-please on `main`, tag-triggered artifacts, consumer `install.sh` without a full clone.

### Binary release train (this repo)

| Step | Where |
|------|--------|
| Version + changelog PR | release-please → merge Release PR → tag `vX.Y.Z` |
| Build tarballs | [`.github/workflows/release.yml`](.github/workflows/release.yml) or locally `make release-artifacts` → [`tool/release/build_release_artifacts.sh`](tool/release/build_release_artifacts.sh) |
| Outputs | `dist/release/flutter_mcp_<version>_<triple>.tar.gz` + [`dist/release/checksums.txt`](dist/release/checksums.txt) (SHA-256 per tarball) |
| Attach to GitHub Release | CI on tag (same filenames as `checksums.txt` entries) |

Before merge, run `make check-contracts` (`check_version_sync.sh`, skill assets drift). Bundled skill: **`flutter-mcp-toolkit-repo-maintainer`** (`.cursor/skills/flutter-mcp-toolkit-repo-maintainer`).

### Consumer install + checksum verification ([`install.sh`](install.sh))

End users should install from **GitHub Release assets**, not `git clone`:

```bash
curl -fsSL https://raw.githubusercontent.com/Arenukvern/mcp_flutter/main/install.sh | bash
# pinned:
curl -fsSL https://raw.githubusercontent.com/Arenukvern/mcp_flutter/main/install.sh | bash -s -- --version vX.Y.Z
```

**Checksum flow** (maintainers: keep CI and `install.sh` in sync):

1. Download `flutter_mcp_<version>_<triple>.tar.gz` from `https://github.com/Arenukvern/mcp_flutter/releases/download/v<version>/`.
2. Download `checksums.txt` from the same release URL.
3. Find the line for the archive: `sha256sum_value  flutter_mcp_<version>_<triple>.tar.gz`.
4. Compute SHA-256 locally (`sha256sum` or `shasum -a 256`) and compare; `install.sh` aborts on mismatch.
5. Extract tarball and install `bin/flutter-mcp-toolkit` and `bin/flutter-mcp-toolkit-server` to `$HOME/.local/bin` (or `--install-dir`).

Published triples: `darwin-arm64`, `linux-x64` only. Intel macOS is unsupported for published binaries (install from source).

When changing artifact names or checksum layout, update **`tool/release/build_release_artifacts.sh`**, **`install.sh`**, and **`.github/workflows/release.yml`** in the same PR.
