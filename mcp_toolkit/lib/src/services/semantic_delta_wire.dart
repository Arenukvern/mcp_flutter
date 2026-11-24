import 'package:universal_automation_semantics/universal_automation_semantics.dart';

/// Default row budget for timeout / await-change delta payloads.
const int defaultDeltaRowCap = 20;

final RegExp _contractIdentifierPattern = RegExp(r'^[a-z]+(\.[a-z_]+)+$');

/// Whether [label] looks like a Semantics contract identifier (`nav.item`).
bool identifierLooksLikeContract(String label) =>
    _contractIdentifierPattern.hasMatch(label);

String _rowLabel(ObservedNode observed) {
  final name = observed.node.name;
  if (name != null && name.isNotEmpty) return name;
  final identifier = observed.node.attributes['identifier'];
  return identifier ?? '';
}

Map<String, Object?> _observedRow(ObservedNode observed) => <String, Object?>{
  'ref': observed.ref,
  'label': _rowLabel(observed),
};

/// Structured +/−/~ rows for wire responses until upstream adds delta JSON.
Map<String, Object?> structuredDeltaFrom(ObservationDelta delta) =>
    <String, Object?>{
      'added': <Map<String, Object?>>[
        for (final node in delta.added) _observedRow(node),
      ],
      'removed': <Map<String, Object?>>[
        for (final node in delta.removed) _observedRow(node),
      ],
      'changed': <Map<String, Object?>>[
        for (final node in delta.changed) _observedRow(node.current),
      ],
    };

/// Caps rendered delta text to [maxRows] and surfaces [deltaTruncated].
Map<String, Object?> cappedDeltaRender(
  ObservationDelta delta, {
  int maxRows = defaultDeltaRowCap,
}) {
  final totalRows =
      delta.added.length + delta.removed.length + delta.changed.length;
  final deltaTruncated = totalRows > maxRows;
  return <String, Object?>{
    'delta': deltaTruncated
        ? _truncateDeltaRender(delta, maxRows: maxRows)
        : delta.render(),
    'deltaTruncated': deltaTruncated,
    ...structuredDeltaFrom(delta),
  };
}

String _truncateDeltaRender(ObservationDelta delta, {required int maxRows}) {
  if (delta.isEmpty) return '# no change';
  var budget = maxRows;
  final buffer = StringBuffer(
    '# delta +${delta.added.length} -${delta.removed.length} '
    '~${delta.changed.length}',
  );
  for (final observed in delta.added) {
    if (budget <= 0) break;
    buffer.write('\n+ ${_rowLabel(observed)}');
    budget--;
  }
  for (final observed in delta.removed) {
    if (budget <= 0) break;
    buffer.write('\n- ${_rowLabel(observed)}');
    budget--;
  }
  for (final change in delta.changed) {
    if (budget <= 0) break;
    buffer.write('\n~ ${_rowLabel(change.current)}');
    budget--;
  }
  final hidden = totalDeltaRows(delta) - (maxRows - budget);
  if (hidden > 0) {
    buffer.write('\n# …$hidden more rows truncated');
  }
  return buffer.toString();
}

int totalDeltaRows(ObservationDelta delta) =>
    delta.added.length + delta.removed.length + delta.changed.length;