# Visual State MCP Architecture

## What

A system that exposes Flutter's widget tree and visual state through MCP resources, enabling efficient debugging and state inspection.

### Core Concepts

1. **Visual State Resources**

   - Viewport state (what's visible)
   - Widget nodes (individual elements)
   - Logical chunks (grouped elements)
   - State changes (updates and diffs)

2. **Resource URIs**
   ```
   visual://{app_id}/viewport/{id}  # Current view
   visual://{app_id}/node/{id}      # Widget state
   visual://{app_id}/chunk/{id}     # Grouped state
   ```

## How

### 1. State Capture

- Hook into Flutter's widget tree
- Track viewport visibility
- Monitor state changes
- Create efficient diffs

### 2. Chunking Strategy

- Split by viewport visibility
- Group by logical components
- Cache frequently accessed parts
- Lazy load off-screen content

### 3. Resource Access

```typescript
// Get viewport state
{
  uri: "visual://app/viewport/main",
  content: {
    visible: ["node-1", "node-2"],
    bounds: {top: 0, height: 800},
    chunks: ["chunk-1"]
  }
}

// Get specific node
{
  uri: "visual://app/node/budget-display",
  content: {
    type: "Text",
    value: "$150.00",
    bounds: {...},
    state: {...}
  }
}
```

### 4. Update Flow

1. Detect widget/state changes
2. Identify affected resources
3. Create minimal diffs
4. Notify subscribed clients
5. Update cache

## Why

### Problems Solved

1. **Context Overflow**

   - Large widget trees exceed context limits
   - Full state dumps are inefficient
   - Hard to track real-time changes

2. **Debug Complexity**

   - Difficult to match code to visual state
   - Hard to track state changes
   - Complex widget relationships

3. **Performance Impact**
   - Full tree serialization is slow
   - State monitoring affects app performance
   - Large memory footprint

### Benefits

1. **Efficient Access**

   - Load only what's needed
   - Minimal memory usage
   - Fast state updates

2. **Better Debugging**

   - Clear resource structure
   - Real-time state tracking
   - Easy navigation

3. **Standard Protocol**

   - Uses existing MCP infrastructure
   - Well-defined security model
   - Built-in discovery

4. **Developer Experience**
   - Intuitive resource URIs
   - Predictable update flow
   - Simple integration
