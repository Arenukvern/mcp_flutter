---
name: repo-brand-identity
description: Establishes, maintains, and governs visual brand identity systems for repository projects (such as Skill Steward), including palettes, vector logos, README status badges, and documentation tone. Use when designing branding, creating custom SVG/Shields.io badges, or adding/updating brand asset guides.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.1.0"
  category: governance
paths:
  - "docs/brand.mdx"
  - "docs/brand/**"
  - "README.md"
---

# Repository brand identity

Define, implement, and govern a quiet, high-craft visual and verbal brand identity system for repositories and package toolkits, avoiding corporate hype and generic visual clutter.

## When to use

- Designing a repository's visual assets, palette, or logo marks.
- Creating and hosting custom brand-aligned SVG badges.
- Formatting Shields.io status badges with embedded base64 SVG logos.
- Documenting hero cover image prompt provenance for reproduction.
- Enforcing tone guidelines and visual asset governance across surfaces.

## Workflow: establishing a brand identity

Follow these stages to establish a repository brand per ADR 0012:

```text
1. Rationale ──► 2. Palette ──► 3. Vector Marks ──► 4. Badges ──► 5. Hero Rasters ──► 6. Governance
```

### 1. Brand Essence & Rationale
- Write a core essence summarizing the project's spirit (e.g. "long-term stewardship", "absence of noise is the signal").
- Avoid generic tech themes; favor artisan/craft concepts.

### 2. Palette Selection
- Define hex codes for both **Light** and **Dark** modes (e.g. background/paper, body text, primary accent, highlights).
- Enforce contrast: all text/background pairs must pass WCAG AA (target AAA for documentation).
- Max 3 colors per surface to maintain visual restraint.

### 3. Vector Master Specifications
- Produce canonical vector logos inside `docs/brand/assets/svg/` using `currentColor` so they inherit the color of their rendering context.
- Use a stable viewBox (e.g. `200 200`) and optimize stroke widths for small-scale legibility.
- Never add drop shadows, gradients, or literal details.

### 4. Creating & Hosting Badges
To showcase that a package is maintained under the brand, construct status badges in two ways:

#### Option A: Custom SVG Pill Badges (Recommended)
Build a bespoke, brand-aligned badge SVG file (e.g. `badge-solid.svg`):
1. **Capsule Shape:** `<rect width="192" height="28" rx="14" fill="#BACKGROUND" />`
2. **Nested Emblem:** Wrap the canonical vector logo path in a nested `<svg>` tag at fixed coordinates, e.g., `<svg x="7" y="5" width="18" height="18" viewBox="0 0 200 200">`.
3. **Optimized Strokes:** Scale stroke widths of the nested emblem to remain crisp at small sizes (e.g., scale 10x thicker to compensate for scale-down).
4. **Typography:** Use a robust system-ui font-family and set explicit margins: `<text x="32" y="17.5" font-family="system-ui, sans-serif" font-size="10.5" fill="#TEXT">... <tspan font-weight="bold">...</tspan></text>`.
5. **Hosting:** Host SVGs directly in the GitHub repo and link them in READMEs via:
   `[![Badge](https://raw.githubusercontent.com/USER/REPO/main/docs/brand/assets/svg/badge-name.svg)](LINK)`

#### Option B: Shields.io base64 Badges
If using Shields.io, embed a customized logo rather than using third-party defaults:
1. Strip comments, titles, metadata, and newlines from a simplified variant of your SVG.
2. Convert the clean SVG string into **base64** format.
3. Pass the base64 string directly into the Shields.io URL logo parameter:
   `https://img.shields.io/badge/Label-Value-HEX_COLOR?logo=data:image/svg%2Bxml;base64,BASE64_STRING`

**Helper: Base64-encoding an SVG in terminal**
Run this Node.js one-liner to strip metadata/comments and output the clean base64 string:
```bash
node -e "const fs = require('fs'); const clean = fs.readFileSync('logo.svg', 'utf8').replace(/<!--.*?-->/gs, '').replace(/<title>.*?<\/title>/gs, '').replace(/<desc>.*?<\/desc>/gs, '').replace(/\s+/g, ' ').trim(); console.log(Buffer.from(clean).toString('base64'));"
```

### 5. Hero & Cover Illustration
- Prefer metaphorical, artistic rasters (cinematic compositions with negative space) over literal representations of tools, robots, or code.
- Record the exact generation prompt in `docs/brand.mdx` for provenance.
- Optimize images for size: target `<150 KiB` for wide covers, `<80 KiB` for smaller squares.

### 6. Verbal Tone of Voice
- **Avoid:** Marketing jargon ("unlock", "revolutionary", "powerful", "ultimate").
- **Prefer:** Restrained, precise, ritual-oriented descriptions ("this belongs here / does not belong here", "validate before merge").

---

## Brand asset governance

- **Location:** All brand assets (logos, heroes, badges) must live under `docs/brand/` to keep the root directory clean.
- **Verification:** Do **not** write automated validators or extend CLI tools to check brand assets. Maintain brand integrity through human code review and documentation checklists.
- **Log changes:** Document all brand-related updates in `docs/brand.mdx` and log public-facing changes using changesets (`pnpm changeset`).

---

## Install (end users)

```bash
npx skills add arenukvern/skill_steward --skill repo-brand-identity
```

## Sources

See [references/sources.md](references/sources.md). When researching, follow `skill-source-citations`.
