---
alwaysApply: true
---

# FAQ Documentation Usage Guide

Quick reference for when to use DESIGN_FAQ.md vs DX_FAQ.md.

**Q: What is DESIGN_FAQ.md for?**
A: Explains WHY design decisions were made. Use when maintaining the ECS codebase, understanding architectural choices, or making changes that affect core systems. Answers questions like "Why do we use archetypes?" or "Why is flush order important?"

**Q: What is DX_FAQ.md for?**
A: Explains HOW to use the ECS API. Use when writing application code, creating systems, or learning the API. Answers questions like "How do I query entities?" or "How do I create a schedule?"

**Q: What format should DX_FAQ.md use?**
A: **Memory Palace Format** - Spatial organization with mental "locations" (🏠 World Hub, 🏭 Entity Factory, etc.) containing embedded code patterns. This format is optimized for AI agent memory retention through spatial associations and instant recall.

**Q: When should I reference DESIGN_FAQ.md?**
A: When you need to understand:

- Architectural rationale (why archetypes, why SoA, why generational IDs)
- Performance trade-offs (why auto-flush, why column abstraction)
- Internal design decisions (why flush order, why command queue)
- Making changes to core ECS systems

**Q: When should I reference DX_FAQ.md?**
A: When you need to know:

- How to use the API (queries, schedules, entity access)
- Code examples for common tasks
- Practical usage patterns
- Writing application code (not maintaining ECS itself)

**Q: Can I use both FAQs together?**
A: Yes. DESIGN_FAQ explains why `WorldEntity` vs `WorldEntityMut` exist, while DX_FAQ shows how to use them. They complement each other - no duplication.

**Q: Which FAQ should I update?**
A: Update DESIGN_FAQ.md when making architectural changes or design decisions. Update DX_FAQ.md when adding new API features or improving developer experience examples.
