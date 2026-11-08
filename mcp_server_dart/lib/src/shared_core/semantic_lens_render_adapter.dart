// Copyright (c) 2025, Flutter Inspector MCP Server authors.
//
// Compatibility adapter: pub.dev `universal_automation_semantics` 0.2.x does not
// ship [SemanticLens] (requires unpublished interface 0.4). Preserves the
// public semantic_snapshot lens contract (`standard` / `compact` / `design`) by
// porting the observation render grammar from UA semantics @ 1c6f798 until
// hosted interface 0.4 lands.

import 'package:universal_automation_interface/universal_automation_interface.dart';
import 'package:universal_automation_semantics/universal_automation_semantics.dart';

enum HostedSemanticLens { standard, compact, design }

HostedSemanticLens hostedSemanticLens(String? lensName) => switch (lensName) {
  'compact' => HostedSemanticLens.compact,
  'design' => HostedSemanticLens.design,
  _ => HostedSemanticLens.standard,
};

/// Renders family observation text with lens fidelity on hosted semantics 0.2.x.
String renderHostedSemanticLens({
  required Snapshot snapshot,
  required Observation observation,
  required HostedSemanticLens lens,
}) {
  final nodes = observation.nodes;
  final lensName = lens == HostedSemanticLens.standard ? '' : ' lens=${lens.name}';
  final buffer = StringBuffer()
    ..write(
      '# observation rev=${snapshot.revision} walked=${observation.walkedCount} '
      'shown=${nodes.length}$lensName',
    );
  var currentPane = '';
  void section(String name) {
    buffer.write('\n# pane $name');
    currentPane = name;
  }

  for (final observed in nodes) {
    final paneName = observed.pane ?? 'main';
    if (paneName != currentPane) section(paneName);
    if (lens == HostedSemanticLens.compact && _isNoise(observed)) continue;
    buffer.write(
      '\n${'  ' * observed.offsetDepth}${_line(observed, lens)}',
    );
  }
  if (lens == HostedSemanticLens.design) {
    _appendDesignClusters(buffer, nodes);
  }
  return buffer.toString();
}

bool _isNoise(ObservedNode observed) {
  final node = observed.node;
  return (node.name == null || node.name!.isEmpty) &&
      (node.value == null || node.value!.isEmpty) &&
      !node.attributes.containsKey('identifier') &&
      (node.role == 'generic' || node.role == 'scrollable');
}

const Map<String, String> _shortRoles = {
  'button': 'btn',
  'textbox': 'txt',
  'text': 'lbl',
  'heading': 'hdr',
  'scrollable': 'scr',
  'window': 'win',
  'image': 'img',
  'checkbox': 'chk',
  'slider': 'sld',
  'tab': 'tab',
  'menu': 'mnu',
  'link': 'lnk',
  'generic': 'g',
};

String _line(ObservedNode observed, HostedSemanticLens lens) {
  final node = observed.node;
  final compact = lens == HostedSemanticLens.compact;
  final buffer = StringBuffer(observed.ref);
  buffer.write(
    compact
        ? ' ${_shortRoles[node.role] ?? node.role.substring(0, node.role.length.clamp(0, 3))}'
        : ' ${node.role}',
  );
  if (node.name != null) {
    buffer.write(' "${_escape(node.name!)}"');
  }
  if (node.value != null && node.value!.isNotEmpty) {
    final escaped = _escape(node.value!);
    buffer.write(compact ? ' =$escaped' : ' value="$escaped"');
  }
  if ((lens == HostedSemanticLens.design) && node.bounds != null) {
    final bounds = node.bounds!;
    buffer.write(
      ' @(${bounds.left},${bounds.top}) ${bounds.width}x${bounds.height}',
    );
  }
  if (node.attributes['enabled'] == 'false') {
    buffer.write(compact ? ' !dis' : ' [disabled]');
  }
  final identifier = node.attributes['identifier'];
  if (identifier != null && identifier.isNotEmpty) {
    buffer.write(' #$identifier');
  }
  return buffer.toString();
}

String _escape(String text) =>
    text.replaceAll('\\', r'\\').replaceAll('"', r'\"');

void _appendDesignClusters(StringBuffer buffer, List<ObservedNode> nodes) {
  final boundsOf = <AxBounds>[
    for (final observed in nodes)
      if (observed.node.bounds case final bounds?) bounds,
  ];
  if (boundsOf.length < 2) return;
  void cluster(String label, double Function(AxBounds) valueOf) {
    final tally = <int, int>{};
    for (final bounds in boundsOf) {
      final key = (valueOf(bounds) / 4).round();
      tally[key] = (tally[key] ?? 0) + 1;
    }
    final repeats = tally.entries.where((e) => e.value >= 2).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (repeats.isEmpty) return;
    buffer
      ..write('\n# $label ')
      ..write(
        repeats
            .take(6)
            .map((e) => '${e.key * 4}×${e.value}')
            .join(' '),
      );
  }

  cluster('cols', (b) => b.left);
  cluster('rows', (b) => b.top);
  cluster('widths', (b) => b.width);
}
