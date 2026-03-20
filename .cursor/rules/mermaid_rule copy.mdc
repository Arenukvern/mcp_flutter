---
description: when asked to create or edit mermaid diagram
globs: 
alwaysApply: false
---
Rule Name: mermaid_syntax_guide
Description: 
Guidelines for generating valid and readable Mermaid diagrams, particularly flowcharts (graph TD/LR).

1.  **Node and Subgraph Identifiers**:
    *   Prefer simple, alphanumeric identifiers (e.g., `ProcessStep1`, `UserData`) that don't require quoting.
    *   Avoid using special characters like `( ) [ ] { } : . , / \` directly within identifiers if possible.

2.  **Quoting Labels and Titles**:
    *   **Crucial:** ALWAYS enclose node labels and subgraph titles in double quotes (`" "`) if they contain:
        *   Spaces (e.g., `"User Interaction"`)
        *   Special characters: `( ) [ ] { } : . , / \` (e.g., `"Process Data (Type A)"`, `"API Call: /users/get"`)
        *   Mermaid keywords used as text.
    *   Example (Node): `id1["Label with spaces and (parentheses)"]`
    *   Example (Subgraph): `subgraph "Subgraph Title with Spaces"`

3.  **Line Breaks**:
    *   Use `\n` *inside* quoted strings to create line breaks within labels for better readability, especially for longer descriptions or storage keys.
    *   Example: `id2["First Line\nSecond Line"]`

4.  **Arrows and Links**:
    *   Use standard Mermaid link syntax (`-->`, `---`, `-.-`, `==>`).
    *   Add text labels to links using `-- text -->` or `---|text|---`.

5.  **Styling**:
    *   Apply styling using `style` or `classDef` statements *after* the graph definition.
    *   Refer to nodes by their identifier (e.g., `style ProcessStep1 fill:#f9f,stroke:#333`).

6.  **Validation Mindset**:
    *   Mentally review the syntax, paying close attention to quoting rules for labels and titles before finalizing the diagram. Check for mismatched quotes or unquoted special characters.

By following these rules, especially the quoting guidelines for labels and titles containing spaces or special characters, we should avoid common Mermaid parsing errors.