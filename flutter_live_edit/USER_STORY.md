# Live Edit — user story

Everything in this stack is organized around one loop:

**Target → Instruct → Plan → Apply**

| Phase | What the user does | What the system does |
|--------|--------------------|----------------------|
| **Target** | Turn on the overlay, pick a widget (tap, marquee, cycle candidates on **appScene**). | Exposes selection + inspector-shaped context to the model (not a manual property editor). |
| **Instruct** | Type intent in the bubble; optional “discuss before plan”. | Drafts and session state stay in resources; AI backends are chosen per bubble or globally. |
| **Plan** | Review the proposed plan / patch when needed. | Agent produces proposals (`resolve`, validation); debug mode can show model thinking (see PRD). |
| **Apply** | Confirm apply (bubble or panel). | Applies patches, hot reload / validation as implemented; surfaces success or failure. |

This story is **not** “edit widget fields like a designer tool.” The PRD forbids direct property manipulation in the UI; inspector-like data exists only as **context for the model**.

See [PRD.md](PRD.md) for full flows and constraints, and [CONTRACT.md](CONTRACT.md) for tool names and technical vocabulary.
