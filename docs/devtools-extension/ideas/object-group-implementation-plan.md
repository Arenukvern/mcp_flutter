# Plan: Implement Object Group Management in devtools_mcp_extension

**Goal:** Integrate the `ObjectGroup` and `ObjectGroupManager` pattern (based on Flutter DevTools) into the `devtools_mcp_extension` to manage VM service object references effectively and prevent memory leaks in the inspected Flutter application.

**Target Files:**

- `devtools_mcp_extension/pubspec.yaml`
- `devtools_mcp_extension/lib/services/devtools_service.dart`
- (New) `devtools_mcp_extension/lib/services/object_group_manager.dart`

**Steps:**

1.  **Add Dependency:**

    - Add the `uuid` package to `dependencies` in `devtools_mcp_extension/pubspec.yaml`.
    - Run `flutter pub get` within the `devtools_mcp_extension` directory (or allow the IDE to do it).

2.  **Create Core Classes (`object_group_manager.dart`):**

    - Create the file `devtools_mcp_extension/lib/services/object_group_manager.dart`.
    - Implement the `ObjectGroup` class:
      - Constructor requires `debugName`, `VmService`, `isolateId`.
      - Stores `_vmService`, `_isolateId`.
      - Generates and stores a unique `groupName` (using `uuid`).
      - Manages `_disposed` state.
      - `dispose()` method calls `_vmService.disposeObjectGroup(_isolateId, groupName)` and sets `_disposed = true`, with error handling.
    - Implement the `ObjectGroupManager` class:
      - Constructor requires `debugName`, `VmService`, `isolateId`.
      - Stores `_debugName`, `_vmService`, `_isolateId`.
      - Manages `ObjectGroup? _current` and `ObjectGroup? _next`.
      - `next` getter: Lazily creates `_next` `ObjectGroup` using stored dependencies. Handles cases where `_next` might already be disposed.
      - `promoteNext()`: Disposes `_current`, sets `_current = _next`, sets `_next = null`.
      - `cancelNext()`: Disposes `_next`, sets `_next = null`.
      - `dispose()`: Disposes both `_current` and `_next`.

3.  **Integrate Managers into `DevtoolsService`:**

    - In `devtools_service.dart`, add `ObjectGroupManager?` instance variables (e.g., `ObjectGroupManager? _treeGroupManager;`).
    - Modify `connectToVmService`:
      - _After_ `_serviceManager.vmServiceOpened` succeeds and `vmService`/`isolateId` are confirmed non-null, initialize the manager instances (e.g., `_treeGroupManager = ObjectGroupManager(...)`).
      - Add error handling/logging if initialization fails.
    - Create a private helper method `Future<void> _disposeManagers()` that calls `dispose()` on all manager instances and sets them to `null`.
    - Modify `disconnectFromVmService`: Call `await _disposeManagers()` before `notifyListeners()`.
    - Ensure `_disposeManagers()` is also called in the `catch` block of `connectToVmService` if the connection fails _after_ managers might have been partially initialized.

4.  **Refactor VM Call Methods in `DevtoolsService`:**

    - Identify methods making VM calls that need group management (e.g., `getRootWidget`, potentially others like `getProperties`, `getChildren`, `getDetailsSubtree` if they are implemented or added later).
    - For each identified method:
      - Get the required manager instance (e.g., `final treeManager = _treeGroupManager;`). Check if it's null or if the service is disconnected; return an error if so.
      - Get the next group: `final group = treeManager.next;`.
      - Wrap the core VM call logic in a `try...catch` block.
      - Modify the VM service call (`callServiceExtensionOnMainIsolate` or similar) to include `'objectGroup': group.groupName` in its arguments map.
      - Inside the `try` block, _after_ the `await` for the VM call completes successfully:
        - Check `if (group.disposed) { /* handle cancellation */ }`.
        - If the result is logically valid, call `await treeManager.promoteNext();` _before_ returning the successful `RPCResponse`.
        - If the result is logically invalid (e.g., `rootWidgetTree.json == null`), call `await treeManager.cancelNext();` before returning the error `RPCResponse`.
      - Inside the `catch` block:
        - Log the error.
        - Call `await _treeGroupManager?.cancelNext();` (use `?` in case the manager was disposed concurrently).
        - Return an error `RPCResponse`.

5.  **Verify Generic `callServiceExtension` (Optional but Recommended):**

    - Review the generic `callServiceExtension` method in `DevtoolsService`.
    - Ensure it simply passes the `objectGroup` argument from its `params` map to `serviceManager.callServiceExtensionOnMainIsolate` if it exists. It should _not_ implement any `promoteNext`/`cancelNext` logic itself.

6.  **Testing:**
    - Write unit tests for `ObjectGroup` and `ObjectGroupManager` if feasible (may require mocking `VmService`).
    - Write integration tests for `DevtoolsService` methods (like `getRootWidget`) that:
      - Verify the `objectGroup` parameter is passed correctly.
      - Perform repeated calls to check for stability and absence of obvious memory leaks in the target app (indirectly observed).
      - Test cancellation/error scenarios.
