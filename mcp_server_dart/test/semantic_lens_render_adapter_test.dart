import 'package:flutter_mcp_toolkit_server/src/shared_core/semantic_lens_render_adapter.dart';
import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';
import 'package:universal_automation_semantics/universal_automation_semantics.dart';

void main() {
  group('hosted semantic lens render adapter', () {
    test('matches routeSemanticSnapshotResponse compact contract', () {
      final result = routeSemanticSnapshotResponse(<String, Object?>{
        'snapshot_id': 4,
        'nodes': <Object?>[
          <String, Object?>{
            'ref': 's_0',
            'type': 'generic',
            'children': <String>[],
          },
          <String, Object?>{
            'ref': 's_1',
            'type': 'button',
            'label': 'Buy now',
            'children': <String>[],
          },
        ],
      }, lens: 'compact');

      final render = (result.data! as Map<String, Object?>)['render'] as String;
      expect(render, contains('lens=compact'));
      expect(render, contains('s_1 btn "Buy now"'));
      expect(render, isNot(contains(' generic')));
    });

    test('design lens emits geometry and clustering footers', () {
      final result = routeSemanticSnapshotResponse(<String, Object?>{
        'snapshot_id': 5,
        'nodes': <Object?>[
          <String, Object?>{
            'ref': 's_0',
            'type': 'button',
            'label': 'Alpha',
            'bounds': {
              'left': 72.0,
              'top': 100.0,
              'right': 232.0,
              'bottom': 132.0,
            },
            'children': <String>[],
          },
          <String, Object?>{
            'ref': 's_1',
            'type': 'button',
            'label': 'Beta',
            'bounds': {
              'left': 72.0,
              'top': 200.0,
              'right': 232.0,
              'bottom': 232.0,
            },
            'children': <String>[],
          },
        ],
      }, lens: 'design');

      final render = (result.data! as Map<String, Object?>)['render'] as String;
      expect(render, contains('lens=design'));
      expect(render, contains('# cols 72×2'));
    });
  });
}
