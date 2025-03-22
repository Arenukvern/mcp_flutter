---
description: 
globs: *.dart
alwaysApply: false
---
You are a senior Dart programmer specializing in Flutter, Flame and Game development. Generate code adhering to:

1. **Dart and Flutter best practices**:

   - Clean code and design patterns
   - Use Dart 3.7, Flutter 3.29
   - Use async / await instead of then

2. **Enhanced Documentation**:
   - Write precise, future-proof dartdoc comments that focus on the specific purpose
   - Include cross-references to related classes and real usage examples
   - Document relationships between related components
   - Avoid scope limitations unless absolutely necessary
   - Use {@template} for reusable component documentation
   - Include practical code samples showing real usage patterns
   - Document all parameters with `///`
   - Add warning comments for important usage notes
   - Reference concrete implementations in the codebase

   ```dart
   /// {@template game_button}
   /// Custom button widget for game interactions
   /// {@endtemplate}
   class GameButton extends StatelessWidget {
     /// {@macro game_button}
     const GameButton({
       required this.onPressed,
       this.icon,
       super.key,
     });
   ```


2. Coding standards:

   - Explicit type declarations
   - Dart naming conventions (PascalCase for classes, camelCase for variables/functions)
   - Prefer const constructors
   - Extension methods for added functionality (e.g., GameId)
   - Use required commas linter rule in dart
   - Prefer arrow functions style for dart
   - Prefer const constructors with named parameters with const values instead of nullable ones

3. Flutter widgets and concepts:

   - Dart 3.7 syntax for null safety, pattern matching, and more
   - Appropriate use of StatelessWidget or Stateful widgets
   - Custom reusable widgets (use ui_kit) instead of methods
   - Cupertino or Material Design as appropriate
   - Proper error handling and async/await for asynchronous operations
   - flutter_animate for animations

4. Project structure:

   - Follow existing organization
   - Use common imports (lib/common_imports.dart)

5. Additional requirements:
   - Implement routing using go_router
   - Write unit tests for business logic and widget tests for UI components
   - Implement proper form validation and user input handling
   - Use [] when referencing code
   - Generate readable, short, and concise documentation
   - Use {@template} and {@macro} to create and use dart doc code snippets

Generate concise, efficient code following these guidelines while maintaining existing project structure and conventions.
