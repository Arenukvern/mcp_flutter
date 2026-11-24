// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

/// Shared tool description for [semantic_snapshot] / `fmt_semantic_snapshot`.
const String semanticSnapshotToolDescription =
    'Get a compact semantic tree of interactive widgets with refs for '
    'interaction tools (tap_widget, enter_text, etc.). Refs number the full '
    'walk — a filtered snapshot still resolves everywhere. Narrow with '
    'identifierPrefix (Semantics identifier), labelPrefix (visible label), '
    'subtreeOf, fields, and maxNodes. Set render:true for numbered family '
    'text; diff:true for +/-/~ rows against the prior same-filter snapshot '
    '(baseline:null with baselineReason on the first call). lens selects '
    'render density '
    '(standard, compact, design). Desktop/web hover controls may be absent '
    'until you hover and snapshot again.';

/// Shared tool description for [wait_for] / `fmt_wait_for`.
const String waitForToolDescription =
    'Wait until a UI predicate holds (or timeout) and return a semantic snapshot '
    'envelope. Matched successes include nodes; `changed` with `settled:false` '
    'attaches the last peek (refBound:false, refs stripped) plus delta. Prefer '
    'changed or diff over keyword filters on a static snapshot when you do not '
    'know the text in advance. Default timeout 5000ms, max 30000ms.';

/// Predicate shapes documented in the wait_for JSON Schema.
const String waitForPredicateKindsDescription =
    'Predicate map shapes: '
    '{kind:"time", ms:int, observe?:bool} — observe defaults true and returns '
    'a peek snapshot envelope (no snapshot_id bump); false sets observed:false '
    'and omits nodes | '
    '{kind:"text", text:String} | {kind:"noText", text:String} | '
    '{kind:"node", identifier:String, selected/enabled/focused/checked/'
    'toggled:bool, absent:bool} | '
    '{kind:"stable", stableWindowMs:int} | {kind:"noError"} | '
    '{kind:"changed", since:<snapshotId>, settleMs?:int} — diffs against a '
    'prior public snapshot in the observation ring (capacity 32; '
    'baseline_evicted when since was evicted). When the tree moved but '
    'settleMs could not complete before timeout, matched:true, settled:false '
    'returns delta plus a peek snapshot envelope (refBound:false).';
