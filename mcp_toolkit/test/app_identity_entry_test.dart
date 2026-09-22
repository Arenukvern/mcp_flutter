import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  group('app_identity entry', () {
    final binding = MCPToolkitBinding.instance;

    Future<AgentResult> callIdentity() {
      final entry = getFlutterMcpToolkitEntries(
        binding: binding,
      ).byName('app_identity');
      final registration = entry.toRegistration();
      return registration.execute(
        AgentInvocation(
          descriptor: registration.descriptor,
          arguments: const <String, Object?>{},
        ),
      );
    }

    tearDown(() => binding.setAppIdentity(label: null));

    test('reports no label until the app names itself', () async {
      final result = await callIdentity();

      expect(result.data['label'], isNull);
    });

    test('reports the label the app set', () async {
      binding.setAppIdentity(label: '  my_app · staging  ');

      final result = await callIdentity();

      expect(result.data['label'], equals('my_app · staging'));
    });

    test('an empty label counts as unnamed', () {
      binding
        ..setAppIdentity(label: 'named')
        ..setAppIdentity(label: '   ');

      expect(binding.appIdentityLabel, isNull);
    });
  });
}
