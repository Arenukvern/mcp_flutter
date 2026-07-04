// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import '../connection/connection_override.dart';

export 'package:intentcall_schema/intentcall_schema.dart'
    show
        clientResourceReadInputSchema,
        clientResourceTemplateReadInputSchema,
        inputSchemaFromDynamicRegistrationMap;

const _gestureDirections = <String>['up', 'down', 'left', 'right'];

const _screenshotModeValues = <String>[
  'auto',
  'flutter_layer',
  'desktop_window',
];

const _permissionPolicyValues = <String>[
  'check_only',
  'auto_request_once',
  'request_always',
];

/// Shared JSON Schema for [tap_widget] / `fmt_tap_widget` (app + server catalog).
Map<String, Object?> tapWidgetInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['ref'],
  'properties': <String, Object?>{
    'ref': <String, Object?>{
      'type': 'string',
      'description': 'Widget ref from semantic_snapshot (e.g. "s_0").',
    },
    'snapshotId': <String, Object?>{
      'type': 'integer',
      'description':
          'Optional: snapshotId input. Use the snapshot_id returned by most recent '
          'semantic_snapshot. If provided and stale, the call fails '
          'with stale_snapshot.',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [semantic_snapshot] / `fmt_semantic_snapshot`.
Map<String, Object?> semanticSnapshotInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'properties': <String, Object?>{'connection': connectionOverrideJsonSchema()},
};

/// Shared JSON Schema for [wait_for] / `fmt_wait_for`.
Map<String, Object?> waitForInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['predicate'],
  'properties': <String, Object?>{
    'predicate': <String, Object?>{
      'type': 'object',
      'additionalProperties': true,
      'description':
          'Predicate map. Shapes: '
          '{kind:"time", ms:int} | '
          '{kind:"text", text:String} | '
          '{kind:"noText", text:String} | '
          '{kind:"stable", stableWindowMs:int}, '
          '{kind:"noError"}',
    },
    'timeoutMs': <String, Object?>{
      'type': 'integer',
      'minimum': 1,
      'maximum': 30000,
      'description': 'Timeout in ms (default 5000, max 30000).',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [enter_text] / `fmt_enter_text`.
Map<String, Object?> enterTextInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['ref', 'text'],
  'properties': <String, Object?>{
    'ref': <String, Object?>{
      'type': 'string',
      'description': 'Text field ref.',
    },
    'text': <String, Object?>{
      'type': 'string',
      'description': 'Text to enter.',
    },
    'snapshotId': <String, Object?>{
      'type': 'integer',
      'description':
          'Optional: snapshotId input. Use the snapshot_id returned by most recent '
          'semantic_snapshot. If provided and stale, the call fails '
          'with stale_snapshot.',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [reveal_search] / `fmt_reveal_search`.
Map<String, Object?> revealSearchInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['query'],
  'properties': <String, Object?>{
    'query': <String, Object?>{
      'type': 'string',
      'description': 'Target text or identifier to find in semantic snapshots.',
    },
    'matchBy': <String, Object?>{
      'type': 'string',
      'enum': <String>['text', 'identifier', 'label', 'value', 'hint'],
      'default': 'text',
      'description':
          'Bounded selector field. "text" searches label, value, and hint.',
    },
    'direction': <String, Object?>{
      'type': 'string',
      'enum': _gestureDirections,
      'default': 'down',
      'description': 'Scroll direction between snapshots.',
    },
    'maxAttempts': <String, Object?>{
      'type': 'integer',
      'minimum': 0,
      'maximum': 10,
      'default': 5,
      'description':
          'Maximum scroll attempts after the initial snapshot (default 5).',
    },
    'distance': <String, Object?>{
      'type': 'number',
      'minimum': 1,
      'maximum': 2000,
      'default': 300,
      'description': 'Scroll distance in logical pixels between attempts.',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [scroll] / `fmt_scroll`.
Map<String, Object?> scrollInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['direction'],
  'properties': <String, Object?>{
    'direction': <String, Object?>{
      'type': 'string',
      'enum': _gestureDirections,
      'description': 'Scroll direction: up, down, left, right.',
    },
    'ref': <String, Object?>{
      'type': 'string',
      'description': 'Optional ref to scroll from.',
    },
    'distance': <String, Object?>{
      'type': 'number',
      'description': 'Scroll distance in logical pixels (default: 300).',
    },
    'snapshotId': <String, Object?>{
      'type': 'integer',
      'description':
          'Optional: snapshotId input. Use the snapshot_id returned by most recent '
          'semantic_snapshot. If provided and stale, the call fails '
          'with stale_snapshot.',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [long_press] / `fmt_long_press`.
Map<String, Object?> longPressInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['ref'],
  'properties': <String, Object?>{
    'ref': <String, Object?>{'type': 'string', 'description': 'Widget ref.'},
    'snapshotId': <String, Object?>{
      'type': 'integer',
      'description':
          'Optional: snapshotId input. Use the snapshot_id returned by most recent '
          'semantic_snapshot. If provided and stale, the call fails '
          'with stale_snapshot.',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [swipe] / `fmt_swipe`.
Map<String, Object?> swipeInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['direction'],
  'properties': <String, Object?>{
    'direction': <String, Object?>{
      'type': 'string',
      'enum': _gestureDirections,
      'description': 'Swipe direction: up, down, left, right.',
    },
    'ref': <String, Object?>{
      'type': 'string',
      'description': 'Optional ref to swipe from.',
    },
    'distance': <String, Object?>{
      'type': 'number',
      'description': 'Swipe distance in logical pixels (default: 300).',
    },
    'snapshotId': <String, Object?>{
      'type': 'integer',
      'description':
          'Optional: snapshotId input. Use the snapshot_id returned by most recent '
          'semantic_snapshot. If provided and stale, the call fails '
          'with stale_snapshot.',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [drag] / `fmt_drag`.
Map<String, Object?> dragInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['fromRef', 'toRef'],
  'properties': <String, Object?>{
    'fromRef': <String, Object?>{
      'type': 'string',
      'description': 'Source widget ref.',
    },
    'toRef': <String, Object?>{
      'type': 'string',
      'description': 'Target widget ref.',
    },
    'snapshotId': <String, Object?>{
      'type': 'integer',
      'description':
          'Optional: snapshotId input. Use the snapshot_id returned by most recent '
          'semantic_snapshot. If provided and stale, the call fails '
          'with stale_snapshot.',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [hover] / `fmt_hover`.
Map<String, Object?> hoverInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['ref'],
  'properties': <String, Object?>{
    'ref': <String, Object?>{'type': 'string'},
    'snapshotId': <String, Object?>{'type': 'integer'},
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [get_recent_logs] / `fmt_get_recent_logs`.
Map<String, Object?> getRecentLogsInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'properties': <String, Object?>{
    'count': <String, Object?>{
      'type': 'integer',
      'description': 'Number of recent log entries (default: 50).',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [fill_form] / `fmt_fill_form`.
Map<String, Object?> fillFormInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['fields'],
  'properties': <String, Object?>{
    'fields': <String, Object?>{
      'type': 'array',
      'items': <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['ref', 'text'],
        'properties': <String, Object?>{
          'ref': <String, Object?>{'type': 'string'},
          'text': <String, Object?>{'type': 'string'},
        },
      },
    },
    'snapshotId': <String, Object?>{
      'type': 'integer',
      'description':
          'Optional: snapshotId input. Use the snapshot_id returned by most recent '
          'semantic_snapshot. Checked on the first field only.',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [handle_dialog] / `fmt_handle_dialog`.
Map<String, Object?> handleDialogInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['action'],
  'properties': <String, Object?>{
    'action': <String, Object?>{
      'type': 'string',
      'description': 'Currently must be "dismiss".',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [navigate] / `fmt_navigate`.
Map<String, Object?> navigateInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['action'],
  'properties': <String, Object?>{
    'action': <String, Object?>{'type': 'string'},
    'route': <String, Object?>{'type': 'string'},
    'arguments': <String, Object?>{
      'type': 'object',
      'additionalProperties': true,
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [evaluate_dart_expression] / `fmt_evaluate_dart_expression`.
Map<String, Object?> evaluateDartExpressionInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['expression'],
  'properties': <String, Object?>{
    'expression': <String, Object?>{
      'type': 'string',
      'description':
          'Dart expression to evaluate (e.g. "MyClass.instance.value").',
    },
    'libraryUri': <String, Object?>{
      'type': 'string',
      'description':
          'Optional library URI for evaluation scope '
          '(e.g. package:myapp/main.dart). Defaults to root library.',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [hot_reload_flutter] / `fmt_hot_reload_flutter`.
Map<String, Object?> hotReloadFlutterInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'properties': <String, Object?>{
    'force': <String, Object?>{
      'type': 'boolean',
      'description':
          'If true, forces a hot reload even if there are no source changes',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [hot_restart_flutter] / `fmt_hot_restart_flutter`.
Map<String, Object?> hotRestartFlutterInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'properties': <String, Object?>{'connection': connectionOverrideJsonSchema()},
};

/// Shared JSON Schema for [get_view_details] / `fmt_get_view_details`.
Map<String, Object?> getViewDetailsInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'properties': <String, Object?>{'connection': connectionOverrideJsonSchema()},
};

/// Shared JSON Schema for [inspect_widget_at_point] / `fmt_inspect_widget_at_point`.
Map<String, Object?> inspectWidgetAtPointInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['x', 'y'],
  'properties': <String, Object?>{
    'x': <String, Object?>{
      'type': 'integer',
      'description': 'Global logical X coordinate.',
    },
    'y': <String, Object?>{
      'type': 'integer',
      'description': 'Global logical Y coordinate.',
    },
    'viewId': <String, Object?>{
      'type': 'integer',
      'description': 'Optional FlutterView id for multi-view apps.',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [select_widget_at_point] (app dynamic tool).
Map<String, Object?> selectWidgetAtPointInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['x', 'y'],
  'properties': <String, Object?>{
    'sessionId': <String, Object?>{
      'type': 'string',
      'description': 'Optional live-edit session id.',
    },
    'x': <String, Object?>{
      'type': 'integer',
      'description': 'Global logical X coordinate.',
    },
    'y': <String, Object?>{
      'type': 'integer',
      'description': 'Global logical Y coordinate.',
    },
    'viewId': <String, Object?>{
      'type': 'integer',
      'description': 'Optional FlutterView id for multi-view apps.',
    },
    'selectionPolicy': <String, Object?>{
      'type': 'string',
      'description':
          'Optional live-edit selection policy when selecting nodes.',
    },
    'targetDomain': <String, Object?>{
      'type': 'string',
      'description':
          'Optional live-edit target domain (e.g. appScene or toolScene).',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [get_app_errors] / `fmt_get_app_errors`.
Map<String, Object?> getAppErrorsInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'properties': <String, Object?>{
    'count': <String, Object?>{
      'type': 'integer',
      'description': 'Number of recent errors to retrieve (default: 4).',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [focus_window] / `fmt_focus_window`.
Map<String, Object?> focusWindowInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'properties': <String, Object?>{
    'targetPid': <String, Object?>{
      'type': 'integer',
      'description': 'Optional VM process id (defaults to the connected VM).',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [get_screenshots] / `fmt_get_screenshots`.
Map<String, Object?> getScreenshotsInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'properties': <String, Object?>{
    'compress': <String, Object?>{
      'type': 'boolean',
      'description': 'Whether to compress the images (default: true).',
    },
    'mode': <String, Object?>{
      'type': 'string',
      'enum': _screenshotModeValues,
      'description':
          'Screenshot mode: auto, flutter_layer, or desktop_window '
          '(default: auto).',
    },
    'permissionPolicy': <String, Object?>{
      'type': 'string',
      'enum': _permissionPolicyValues,
      'description':
          'Permission policy: check_only, auto_request_once, or '
          'request_always (default: check_only).',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [capture_ui_snapshot] / `fmt_capture_ui_snapshot`.
Map<String, Object?> captureUiSnapshotInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'properties': <String, Object?>{
    'errorsCount': <String, Object?>{
      'type': 'integer',
      'description': 'Number of recent errors to include (default: 4).',
    },
    'compress': <String, Object?>{
      'type': 'boolean',
      'description':
          'Whether screenshots should be compressed (default: true).',
    },
    'includeViewDetails': <String, Object?>{
      'type': 'boolean',
      'description': 'Include detailed view/widget data (default: true).',
    },
    'includeErrors': <String, Object?>{
      'type': 'boolean',
      'description': 'Include app errors (default: true).',
    },
    'screenshotMode': <String, Object?>{
      'type': 'string',
      'enum': _screenshotModeValues,
      'description':
          'Screenshot mode: auto, flutter_layer, or desktop_window '
          '(default: auto).',
    },
    'permissionPolicy': <String, Object?>{
      'type': 'string',
      'enum': _permissionPolicyValues,
      'description':
          'Permission policy: check_only, auto_request_once, or '
          'request_always (default: check_only).',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Shared JSON Schema for [hot_reload_and_capture] / `fmt_hot_reload_and_capture`.
Map<String, Object?> hotReloadAndCaptureInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'properties': <String, Object?>{
    'compress': <String, Object?>{
      'type': 'boolean',
      'description': 'Compress screenshots (default: true).',
    },
    'includeSemantics': <String, Object?>{
      'type': 'boolean',
      'description': 'Include semantic snapshot (default: true).',
    },
    'includeErrors': <String, Object?>{
      'type': 'boolean',
      'description': 'Include app errors (default: true).',
    },
    'errorsCount': <String, Object?>{
      'type': 'integer',
      'description': 'Number of errors to include (default: 4).',
    },
    'connection': connectionOverrideJsonSchema(),
  },
};

/// Original interaction catalog (gestures, navigation, forms, hot reload).
///
/// Parity table: `flutter_test_app/INTENTCALL_PLATFORM.md`.
const coreInteractionCatalogCommandNames = <String>[
  'tap_widget',
  'semantic_snapshot',
  'wait_for',
  'enter_text',
  'reveal_search',
  'scroll',
  'long_press',
  'swipe',
  'drag',
  'hover',
  'press_key',
  'get_recent_logs',
  'handle_dialog',
  'navigate',
  'fill_form',
  'evaluate_dart_expression',
  'hot_reload_flutter',
  'hot_restart_flutter',
  'hot_reload_and_capture',
];

/// Host inspection tools beyond the core 19 (Tier A `exec` / `fmt_*`).
const inspectionTierAExecCommandNames = <String>[
  'get_view_details',
  'inspect_widget_at_point',
  'get_app_errors',
  'focus_window',
];

/// Host capture tools (`get_screenshots`, `capture_ui_snapshot`) on the same router.
const captureTierAExecCommandNames = <String>[
  'get_screenshots',
  'capture_ui_snapshot',
];

/// Tier A exec catalog: core 19 + 4 inspection (23 tools).
const tierAExecCatalogCommandNames = <String>[
  ...coreInteractionCatalogCommandNames,
  ...inspectionTierAExecCommandNames,
];

/// Every command name served by [interactionCatalogInputSchemaFor] (23 + 2 capture).
const interactionCatalogInputSchemaForCommandNames = <String>[
  ...tierAExecCatalogCommandNames,
  ...captureTierAExecCommandNames,
];

/// JSON Schema for catalog/exec commands aligned with app dynamic tools and `fmt_*`.
///
/// Covers [interactionCatalogInputSchemaForCommandNames]: the
/// [tierAExecCatalogCommandNames] set plus two capture tools.
/// Returns `null` for commands outside that set.
Map<String, Object?>? interactionCatalogInputSchemaFor(
  final String commandName,
) => switch (commandName) {
  'tap_widget' => tapWidgetInputSchema(),
  'semantic_snapshot' => semanticSnapshotInputSchema(),
  'wait_for' => waitForInputSchema(),
  'enter_text' => enterTextInputSchema(),
  'reveal_search' => revealSearchInputSchema(),
  'scroll' => scrollInputSchema(),
  'long_press' => longPressInputSchema(),
  'swipe' => swipeInputSchema(),
  'drag' => dragInputSchema(),
  'fill_form' => fillFormInputSchema(),
  'hover' => hoverInputSchema(),
  'press_key' => pressKeyInputSchema(),
  'get_recent_logs' => getRecentLogsInputSchema(),
  'handle_dialog' => handleDialogInputSchema(),
  'navigate' => navigateInputSchema(),
  'evaluate_dart_expression' => evaluateDartExpressionInputSchema(),
  'hot_reload_flutter' => hotReloadFlutterInputSchema(),
  'hot_restart_flutter' => hotRestartFlutterInputSchema(),
  'hot_reload_and_capture' => hotReloadAndCaptureInputSchema(),
  'get_screenshots' => getScreenshotsInputSchema(),
  'capture_ui_snapshot' => captureUiSnapshotInputSchema(),
  'get_view_details' => getViewDetailsInputSchema(),
  'inspect_widget_at_point' => inspectWidgetAtPointInputSchema(),
  'get_app_errors' => getAppErrorsInputSchema(),
  'focus_window' => focusWindowInputSchema(),
  _ => null,
};

/// Shared JSON Schema for [press_key] / `fmt_press_key`.
Map<String, Object?> pressKeyInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['key'],
  'properties': <String, Object?>{
    'key': <String, Object?>{'type': 'string'},
    'ctrl': <String, Object?>{'type': 'boolean'},
    'shift': <String, Object?>{'type': 'boolean'},
    'alt': <String, Object?>{'type': 'boolean'},
    'meta': <String, Object?>{'type': 'boolean'},
    'connection': connectionOverrideJsonSchema(),
  },
};
