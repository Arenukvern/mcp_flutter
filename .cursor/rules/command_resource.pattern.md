---
description: When writing commands or resources
globs:
  - "**/*.cmd.dart"
  - "**/*.src.dart"
alwaysApply: false
---

**Writing Code Protocol**

- Export files from its folders using barrel file (resources/resources.dart, commands/commands.dart etc.).
- Do not rely on strings, use enums.
- Use context.read/context.select to subscribe to observable state in build methods.

**Intent and Implementation Consistency**

**Command-Resource Pattern**

The relationship between Commands, Resources, and Services is the backbone of the application's architecture, ensuring a clean separation of concerns.

- **Commands**: Execute atomic **transactions**.
- **Services**: Provide reusable **capabilities**.
- **Resources**: Hold and expose UI **state**.

A typical data flow is: `UI -> Command -> Service -> Resource -> UI`.

- **Commands**: Pure business logic containers
  - **Role**: To execute a single, discrete business transaction (e.g., "Save Character") in response to a UI event. Commands are the _only_ part of the application allowed to orchestrate state changes.
  - **Responsibilities**:
    - Translate a UI event into a state change.
    - Validate input for a specific action.
    - Call one or more Services to perform the necessary work.
    - Update one or more Resources with the result of the operation.
  - **Characteristics**:
    - **Short-lived & Stateless**: A Command is created, executed, and discarded for a single action. It holds no state itself.
    - **Triggered by UI**: They are the bridge between user intent (a button click, a debounced text change) and the system's reaction.
  - Expose logic via `execute()` method. Create private methods if needed for clarity
  - Named as `{Action}{Resource}Command`
  - File named as {snake_case}.cmd.dart
  - The Dart class name within a command file must be the `PascalCase` version of the file name. For example, `load_nutrients.cmd.dart` must contain `class LoadNutrientsCommand`.
  - Can read/update multiple resources
  - Contain all transformative logic
  - Commands are executed based on user or other actions

- **Services**: High-level capability providers
  - **Role**: To encapsulate a major area of application functionality and provide a stable, reusable API for a core domain concern (e.g., `WorkspaceService`).
  - **Responsibilities**:
    - Interacting with the Data API (file system I/O, parsing).
    - Managing long-running processes (e.g., watching a directory).
    - Encapsulating complex, multi-step business workflows.
  - **Characteristics**:
    - **Long-lived**: Often instantiated once and used throughout the application's lifecycle.
    - **Called by Commands**: Services should never be called directly from the UI.
    - **Dependencies**: Depend on the Data API and other low-level utilities. They do not depend on Commands or UI.

- **Resources**: Pure data containers
  - **Role**: To hold, manage, and expose UI state. They notify listeners when their data changes, enabling the UI to be reactive.
  - Named as `{Domain}Resource`
  - File named as {snake_case}.src.dart
  - Place ResourceData (BLoC models, see below) and support types to {snake_case}.src.data.dart
  - Minimal business logic related to state management. Focus on holding and managing state, not complex domain logic.
  - **Immutable Resources**
    - Use for all Flutter UI Widget related data.
    - Use `BLoC Style`, see explanation below.
    - For resources representing collections (lists, maps), always extend `OrderedMapNotifier`/`OrderedListNotifier` from `xsoulspace_state_utils`.
    - Protocol defining `ResourceData` class:
      - If the domain scope is similar: `KeyboardSetting`, `MusicSettings`, `GridSettings` etc..
      - If it is related to one model, like `Apple` has properties: color, shape etc..
      - If that's the case, always create `ResourceData`.
      - Otherwise create for every primitive different Resource, like `GameStatusResource extends ValueNotifier` etc.
      - In the context of `Immutable Resources`, `BLoC style` refers to the practice of separating the immutable data structure (the "State" in BLoC terminology) into its own Data class (`Model`). This Data class is then held and managed by the Resource class (which acts as a simplified "BLoC"), using `ValueNotifier`, `OrderedMapNotifier`, or `OrderedListNotifier` to notify listeners of state changes. This promotes a clear separation of concerns and improves the manageability of immutable state.

  - **Mutable Resources**
    - Pure classes with mutable structures.
    - Use for scenarios demanding ultra-fast, in-place updates: e.g., animation buffers, real-time game state, or any data structure where mutation speed is critical.
    - Optimized for high-frequency, low-latency changes—ideal for render loops, simulations, or transient, performance-sensitive state.
    - For resources representing collections (lists, maps), always extend `OrderedMap`/`OrderedList` from `xsoulspace_state_utils`.
    - Create separate 'Data', if no models exists. Bloc style files for complex data structures. When using in Mutable Resource, Data should have prefix `Mut` and be mutable.
    - Data can be changed in place; updates mutate the existing instance.

  - Resources should provide a clear way to define their initial state. Use factory constructors like `initial()` within the state class for this purpose.
  - Cannot have any dependencies!
