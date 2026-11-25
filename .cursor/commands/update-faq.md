Update `docs/DESIGN_FAQ.mdx` and/or `docs/DX_FAQ.mdx` (and package FAQs under `packages/harness/` or `mcp_toolkit/` when the change is package-local) based on the work in this session.

Goals:

1. **DESIGN_FAQ** — **Why** (design decisions): shortest FAQ form for agents and maintainers. 2–3 sentences per answer; trade-offs; link to the ADR at the end. Do not duplicate ADR bodies.

2. **DX_FAQ** — **How** (usage): Memory Palace with emoji `##` locations and terse, copy-paste commands verified against the repo (`fmtk`, `dart run`, `make`).

# Rules

0. Verify every command and path against the codebase.

1. Prefer new concise rows over long prose; shrink duplicate docs elsewhere by linking.

2. No duplication between DESIGN and DX; no duplication with [NORTH_STAR.mdx](../../docs/NORTH_STAR.mdx).

3. Classify `north_star_impact` when ownership or boundaries shift; `amends` requires ADR + North Star update first.

4. After editing root ADRs, run `rsync -a --delete decisions/ docs/decisions/`.

# Examples

**Q: Why was `select_option` dropped?**  
A: Flutter dropdown semantics vary too much for one MCP tool; hover and fill_form cover supported cases without flaky defaults. [ADR 0005](../../decisions/0005_p2_fill_form_hover_select_option.mdx)

**Harness location — drive showcase:**  
```bash
dart run showcase/drivers/bin/drive_flutter.dart --help
```