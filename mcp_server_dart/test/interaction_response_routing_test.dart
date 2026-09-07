import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('routeInteractionResponse', () {
    test('a delivered gesture routes to success', () {
      final result = routeInteractionResponse('tap_widget', <String, Object?>{
        'success': true,
        'ref': 's_14',
        'via': 'semantic_action',
      });

      expect(result.ok, isTrue);
      expect((result.data! as Map<String, Object?>)['via'], 'semantic_action');
    });

    test('a refused gesture routes to failure and keeps its payload', () {
      final result = routeInteractionResponse('tap_widget', <String, Object?>{
        'success': false,
        'ref': 's_14',
        'error': 'stale_ref',
        'hint': 'Call semantic_snapshot again and use the fresh ref.',
      });

      expect(result.ok, isFalse);
      expect(result.error!.code, CoreErrorCode.interactionFailed);
      expect(result.error!.message, contains('stale_ref'));
      expect((result.error!.details! as Map)['ref'], 's_14');
    });

    test('a stale snapshot answers with ok, not success, and still fails', () {
      final result = routeInteractionResponse('enter_text', <String, Object?>{
        'ok': false,
        'error': 'stale_snapshot',
        'providedSnapshotId': 2,
        'currentSnapshotId': 5,
      });

      expect(result.ok, isFalse);
      expect(result.error!.message, contains('stale_snapshot'));
    });

    test('a search that found nothing is not a successful call', () {
      // reveal_search reports its verdict in the payload like every other
      // interaction; wrapping it in success sent the caller on to tap a ref
      // that was never returned.
      final result = routeInteractionResponse('reveal_search', <String, Object?>{
        'success': false,
        'error': 'target_not_found',
        'query': 'Invoice 42',
        'attempts': <Object?>[],
      });

      expect(result.ok, isFalse);
      expect(result.error!.code, CoreErrorCode.interactionFailed);
      expect(result.error!.message, contains('target_not_found'));
    });

    test('a payload the toolkit never verdicted counts as a refusal', () {
      final result = routeInteractionResponse('scroll', const <String, Object?>{
        'via': 'pointer_scroll_event',
      });

      expect(result.ok, isFalse);
      expect(result.error!.message, contains('no success in payload'));
    });

    test('the payload hint becomes the recovery the caller reads', () {
      final result = routeInteractionResponse('reveal_search', <String, Object?>{
        'success': false,
        'error': 'scroll_blocked',
        'hint': 'The list is already at that edge — search the other way.',
      });
      final recovery =
          result.error!.toJson()['recovery']! as Map<String, Object?>;

      expect(
        recovery['summary'],
        'The list is already at that edge — search the other way.',
      );
      // No generic command rides along: the causes that carry a hint are
      // answered by different commands, and the wrong one costs a call.
      expect(recovery.containsKey('fix_command'), isFalse);
    });
  });
}
