# Flutter MCP Toolkit — Brand guide

> **One-line brand:** Warm engineering for AI agents that drive Flutter apps — cinematic plastic-toy props on a watercolor canvas, narrated by a Weaver bird.

Master art: `original_logo.png` (1:1, Gemini render). All derivatives are `sips -z` of the master.

---

## 1. Concept — The Collaborative Weaver

The Sociable Weaver builds nests cell-by-cell with the colony. Each new chamber is plugged into the existing structure; no monolithic build, no central architect — just a flock of modular tools that fit together.

That is the toolkit. The **agent** is the Weaver. **Your app** is the nest. The **27 built-in tools** are the cells already in place. **Your own tools** are new chambers you weave in.

The brand expresses this with two textures stacked on every surface:

| Texture | Stands for | In execution |
|---------|------------|--------------|
| **Plastic-toy** (chunky props, specular highlights, perspective tilt) | Tools you can pick up and click together. Tangible, modular, friendly to handle. | Server cube, plug cube, nest, hex chips, phone bezel |
| **Watercolor wash** (cool blue + warm earth, soft grain) | The creative environment around the tools — design, debugging, exploration. | `.wash-cool` / `.wash-warm` background layer |

Voice: **crafted, modular, inviting.** Technically precise (real `fmt_*` names, real refs like `s_7`) but never cold — every demo earns its punchline with a payoff that *feels* good.

---

## 2. Logo & marks

| Mark | File | Use |
|------|------|-----|
| Master | `original_logo.png` | Source of truth; promo cold-open + CTA + marketplace hero |
| Marketplace logo | `logo.png` | Plugin listing card |
| Marketplace icon | `icon.png` | Plugin tile / favicon |
| Mascot | `mascot_collaborative_weaver.png` | Transparent bird for promo journey lanes |

**Clearspace.** Keep at least the height of the bird's head clear on every side. Never crop the PCB plaque off the master.

**Min size.** Master logo ≥ 240px wide on screen. Below that, use the icon.

**Don't.**

| ❌ | Why |
|---|-----|
| Recolor the master logo or mascot | The watercolor + plastic palette is the recognition cue |
| Place the master on a pure-white background | The deep teal canvas (`--bg-canvas`) is part of the mark |
| Add drop shadows to the master in CSS | The master already carries its own painted shadow |
| Use the mascot without the toolkit context (no cube, no nest) anywhere it could read as a children's-book illustration | The Weaver is an *agent persona*, not a generic mascot |

---

## 3. Color tokens

CSS custom properties live in **flutter_mcp_video** `projects/video-projects/v7-weaver-release/compositions/brand-v7-shared.css` (`:root` block). Hex literals below are the canonical brand values — phone-UI internals (Apple-style grays, `#007aff`, `#30d158`) are not brand and stay scoped to mockups.

### 3.1 Surfaces

| Token | Hex | Role |
|-------|-----|------|
| `--bg-canvas` | `#0B1A24` | Deep teal-black base behind the watercolor wash. Every scene. Never pure black. |
| `--bg-elevated` | `#163448` | Agent panels, caption plate |
| `--bg-elevated-low` | `#1A4A6E` | Action button base, action chip |
| `--bg-flutter-deep` | `#0D3D5C` | Server cube shadow / bottom of brand gradient |

### 3.2 Brand primary (Flutter)

| Token | Hex | Role |
|-------|-----|------|
| `--brand-flutter` | `#02569B` | Flutter blue (canonical) — server cube, pillars border |
| `--brand-flutter-bright` | `#1A6BB5` | Server cube top highlight |

### 3.3 Accent (Weaver cyan / code)

The Weaver cyan is the loudest brand voice — it is what reads as "code is alive." Used for emphasis (`em` in headlines + captions), `fmt_*` chips, and journey arrows.

| Token | Hex | Role |
|-------|-----|------|
| `--accent-cyan` | `#64D2FF` | Primary code accent — headline `em`, `fmt_*` chips |
| `--accent-cyan-bright` | `#9EE8FF` | Action button text, max emphasis |
| `--accent-cyan-soft` | `#7EC8E3` | Journey arrows, watercolor highlight |
| `--accent-cyan-fade` | `#B8E8F8` | Fade-out tail, tertiary highlights |

### 3.4 Weaver organic (nest + bird)

| Token | Hex | Role |
|-------|-----|------|
| `--weaver-tan` | `#D4A574` | Nest top, bird highlight |
| `--weaver-brown` | `#8B6914` | Nest mid |
| `--weaver-brown-deep` | `#6B4F10` | Nest bottom shadow |

### 3.5 Plug amber (subagent / dynamic tool)

The plug-cube colorway is the *opposite* of Flutter blue — warm, mischievous, marks user-extended surface.

| Token | Hex | Role |
|-------|-----|------|
| `--plug-yellow` | `#FFD966` | Plug cube highlight |
| `--plug-amber` | `#E8A838` | Plug cube mid |
| `--plug-amber-deep` | `#C4841A` | Plug cube shadow |

### 3.6 Text

| Token | Hex | Role |
|-------|-----|------|
| `--text-primary` | `#F5F5F7` | Default text on dark canvas |
| `--text-caption` | `#F8FBFF` | Caption rail (slightly cooler white) |
| `--text-on-cube` | `#E8F7FF` | Server cube label |
| `--text-on-cube-sub` | `#D4F4FF` | Server cube sub-label |

### 3.7 Pairings + contrast

| Foreground | Background | Use | Approx. contrast |
|------------|------------|-----|------------------|
| `--text-primary` | `--bg-canvas` | Body text | 15:1 ✅ |
| `--accent-cyan` | `--bg-canvas` | Code accent | 11:1 ✅ |
| `--accent-cyan-bright` | `--bg-elevated-low` | Action button | 7:1 ✅ |
| `--accent-cyan` on `--bg-canvas` 25% alpha (recap pill) | — | Pills | passes 4.5:1 |

Rule of thumb: anything carrying real meaning (a `fmt_*` name, a value, a number) must clear AA against its surface. Decorative props (cubes, nest) are exempt — they're not text.

---

## 4. Typography

> **Authoritative font stack.** Use these everywhere. No network fonts — promo renders must be deterministic offline.

| Token | Stack | Use |
|-------|-------|-----|
| `--font-body` | `"Avenir Next", "Trebuchet MS", "Segoe UI", system-ui, sans-serif` | Headlines, captions, labels, UI text |
| `--font-code` | `ui-monospace, "SF Mono", Menlo, monospace` | `fmt_*` names, JSON, code, `init` command |

> Earlier drafts mentioned Nunito / Quicksand — those are **not** the brand stack. Rounded system fonts are the choice because (a) the warm rounded letterforms match the plastic-toy mood and (b) they render identically offline at render time. Do not re-introduce webfonts.

### Scale

| Token | Size | Weight | Tracking | Use |
|-------|------|--------|----------|-----|
| `--fs-headline` | 36px | 700 | normal | One headline per scene |
| `--fs-caption` | 32px | 700 | -0.02em | `.scene-caption` |
| `--fs-action` | 20px | 700 | 0.02em | `.action` (`fmt_*` chip) |
| `--fs-pill` | 20px | 600 | normal | Recap pills, CTA pills |
| `--fs-label` | 14px | 700 | normal | Hex chip labels |

`em` inside a headline or caption means *brand accent* — colors to `--accent-cyan`. Don't bold instead.

---

## 5. Plastic-toy elevation

The plastic-toy look is a **named shadow ramp**, not a free-for-all. Three values cover every prop.

| Token | Shadow | On |
|-------|--------|-----|
| `--elev-prop` | drop + flat ground + inner top-light + inner bottom-shade | Server cube, plug cube, nest, hex chip |
| `--elev-prop-soft` | drop + inner top-light only | Smaller / secondary props |
| `--elev-phone` | deeper drop + ground + dual inner highlight | `.phone-toy` bezel |
| `--elev-panel` | single soft drop | Agent panel, semantic panel |
| `--elev-caption` | drop + inner top-light | `.caption-rail .scene-caption` plate |

Props also tilt slightly to read as 3D objects, not stickers:

| Token | Transform | Use |
|-------|-----------|-----|
| `--tilt-cube` | `perspective(800px) rotateX(4deg)` | Server cube |
| `--tilt-phone` | `perspective(1200px) rotateY(-2deg)` | Phone hero |

---

## 6. Watercolor wash

Two presets, applied as a full-stage `.wash` layer between the canvas and the props.

| Class | Mood | Where |
|-------|------|-------|
| `.wash-cool` | Blue-led, earth tail | Default — debugging, inspection scenes |
| `.wash-warm` | Orange-led, blue tail | Payoff, install, CTA |

Soft grain via `.wash::after` is optional polish; never sharper than 4% opacity.

---

## 7. Scene vocabulary

The brand has two narrative patterns. Pick one per scene; do not mix.

### 7.1 Agent-bubble narrative (the default for vignettes)

Each beat is a labeled text bubble on the left, showing the agent's *role* and the tool/concept it's using, with the app phone on the right. Bubble labels (`CONCEPT`, `TOOL`, `AGENT`, `RESOURCE`, `PATH A`, `PATH B`) act like film captions — clearer than icons for a developer audience reading `fmt_*` names.

| Class | Stands for | When |
|-------|------------|------|
| `.agent-bubble` (+ kicker like `CONCEPT`/`TOOL`/`AGENT`) | One narrative beat — what the agent is doing right now | Every vignette: ¶2 vm-vs-app, ¶3 tools-grid, ¶4 cart, ¶5 game, ¶6 flags |
| `.tool-name` (inside bubble) | The literal `fmt_*` name in code font | When the bubble is a `TOOL` step |
| `.phone-toy` (+ `.phone-hero`) | The thing the user sees | Every vignette payoff |
| `.semantic-panel` / `.snapshot-recap-mini` / `.dart-panel` | Concept diagrams that aren't bubbles | When the beat IS the concept (semantic map, registration code, snapshot recap) |

**Reading grammar.** Always left-to-right: `agent-bubble(s) → phone`. Bubbles fade-in to mark beat progression; never more than 3 visible at once.

### 7.2 Cinematic brand props (cold-open, install, CTA only)

The plastic-toy props are reserved for the *bookend* scenes that show the brand itself — not for vignette demos.

| Class | Stands for | Where |
|-------|------------|-------|
| `.mascot` (PNG) | Sociable Weaver — the agent persona | Cold-open watermark, CTA logo |
| `.prop-server-cube` | MCP server (Flutter F) | Install harness diagram |
| `.prop-plug-cube` | Dynamic / subagent / user-registered tool | Install (init step), CTA recap |
| `.prop-nest` | App registration surface | CTA logo (painted into the master) |
| `.hex-plastic` | Domain marker (AI · wrench · cart) | CTA logo (painted into the master) |
| `.logo-hero-inline` (master PNG) | The brand mark | CTA hero tile |
| `.harness-diagram` + `.install-terminal` | Same agent harness everywhere | Install ¶7 |

**Reading grammar (install).** Harness panel → arrow chip → toolkit → MCP cube → Flutter card → `init all` plaque.

**Reading grammar (CTA).** Master logo → 27 + verbs grid → install / try-it / share action cards.

---

## 8. Motion

Promo motion lives in GSAP keyframes derived from VO cues. The brand contribution is the *vocabulary*:

| Beat | Easing | Duration | Reads as |
|------|--------|----------|----------|
| Camera push / rig zoom | `power2.inOut` | 0.8–1.2s | "We're moving in" |
| Prop pop-in | `back.out(1.6)` | 0.45s | Plastic snapping into place |
| Journey arrow sweep | `power3.out` | 0.35s | Flow direction |
| `fmt_*` chip appear | `expo.out` | 0.30s | Tool armed |
| Phone payoff | `power2.out` | 0.50s | Result lands |

Full vocabulary: [promo-motion-vocabulary.md](../skills/hyperframes-video/references/promo-motion-vocabulary.md).

---

## 9. Voice & tone

| ✅ Do | ❌ Don't |
|------|---------|
| Lead with the *idea*, then the tool name (teach-before-tool) | Open a scene with a bare `fmt_*` chip |
| Use real refs (`s_7`, `snapshotId`) when they reinforce that the toolkit is precise | Invent fake API names that look plausible but aren't real |
| Name what's broken in plain words ("blind phone", "empty cart") | Use generic engineering jargon ("UI introspection layer") |
| Keep one headline + one diagram per scene | Stack two headlines or a tool wall |
| Subtitles above y=880, scene caption above the beat | Cover the phone with copy |
| Match scene wash to mood (cool for debug, warm for payoff) | Use the same wash on every scene |
| Use bubble narrative for vignettes; cinematic props for bookends (§7) | Use plastic-toy mascot/cube journey inside vignettes — it competes with the actual phone payoff |
| End subtitle cues on `.`, `?`, `!`, or a substantial clause | End cues on a trailing comma — the orphan reads as "unfinished" |

---


## 10. Asset pipeline

| File | Role | Regeneration |
|------|------|-------------|
| `original_logo.png` | Master artwork (1:1) | Hand-rendered (Gemini) — see [README.md](README.md) |
| `mascot_collaborative_weaver.png` | Transparent bird PNG | Hand-cut from master |
| `logo.png` | Marketplace logo | `sips -z <H> <W> original_logo.png --out logo.png` |
| `icon.png` | Marketplace icon | `sips -z 256 256 original_logo.png --out icon.png` |
| `screenshot-{1,2}.png` | Marketplace screenshots | Plugin UI captures |
