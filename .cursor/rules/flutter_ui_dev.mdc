---
description: when creating or modifing flutter widgets
alwaysApply: false
---

# Flutter widgets and concepts:

- Dart 3.11 syntax for null safety, pattern matching, and more
- Appropriate use of StatelessWidget, or Stateful widgets (NO riverpod)
- Custom reusable widgets (use ui_kit) instead of methods
- Cupertino or Material Design as appropriate
- Proper error handling and async/await for asynchronous operations
- flutter_animate for animations

# Widget Composition Guidelines:

1. **Appropriate Widget Granularity**:
   - Prefer fewer, more cohesive widgets over many tiny widgets
   - Extract new widget classes only when they are:
   - Reused in multiple places
   - Complex enough to warrant separation (>10 lines)
   - Logically independent with clear boundaries
   - For simpler UIs, use a single widget with well-commented sections

2. **Code Organization Hierarchy**:
   - First preference: Use comments to separate logical sections within a widget
   - Second preference: Extract logical methods for complex sections (>10 && <30 lines)
   - Last preference: Create new widget classes

3. **Comment-Based Structure**:
   - Use section comments to delineate logical UI parts:

   ```dart
   // Header section
   Column(
      children: [
         // Title
         Text('Title'),
         // Subtitle
         Text('Subtitle'),
      ],
   ),
   ```

4. **Refactoring Decision Tree**:
   - Is the component reused? → Extract widget
   - Is the component >50 lines? → Consider extraction
   - Is the component logically independent? → Consider extraction
   - Otherwise → Keep in parent with comments

5. **Performance Considerations**:
   - Be mindful that each widget adds overhead
   - Prefer fewer widgets for simpler screens
   - Use const constructors aggressively

6. **Documentation Balance**:
   - For single-class approaches, use inline comments instead of class-level docs
   - Reserve detailed documentation for public APIs and complex widgets
   - Document the "why" more than the "what" when using comments
