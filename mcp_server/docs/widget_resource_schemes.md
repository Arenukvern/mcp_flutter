Architecture to capture the widget tree

```mermaid
graph LR
    A[User clicks "Select widget mode" in DevTools Frontend] --> B(DevTools Frontend: Activates selection mode);
    B --> C[User clicks on a widget in the inspected Flutter Application];
    C --> D(DevTools Frontend: Captures click coordinates (x, y));
    D --> E{DevTools Frontend -> DevTools Backend: Send coordinates};
    E -- via communication channel --> F(DevTools Backend: Receives coordinates and initiates hit test);
    F --> G{DevTools Backend -> Flutter Service Protocol: Call `flutter.inspector.hitTest(x, y)`};
    G -- via Service Protocol --> H(Flutter Application's VM: Performs hit test on widget tree);
    H --> I{Flutter Application's VM -> Flutter Service Protocol: Return widget information (e.g., widget type, properties)};
    I -- via Service Protocol --> J(DevTools Backend: Receives widget information);
    J --> K{DevTools Backend -> DevTools Frontend: Send widget information};
    K -- via communication channel --> L(DevTools Frontend: Updates Widget Inspector UI, highlights the selected widget);
    L --> M[End];
```

Option to represent the widget tree as a json object

```json
{
  "metadata": {
    "app_id": "budget_planner",
    "chunk_id": "main_view",
    "total_chunks": 12,
    "timestamp": "2024-03-21T15:30:00.000Z"
  },
  "chunk_map": {
    "main_view": ["header", "content", "footer"],
    "content": ["budget_display", "transactions", "charts"],
    "transactions": ["list_1", "list_2", "list_3"]
  },
  "nodes": {
    // Only immediate children, with references
    "root": {
      "type": "scaffold",
      "children": ["header", "content", "footer"],
      "chunk_refs": {
        "header": "chunk://header",
        "content": "chunk://content",
        "footer": "chunk://footer"
      }
    }
  }
}
```
