import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:dart_mcp/server.dart';
import 'package:test/test.dart';

void main() {
  test('agentResultToReadResourceResult maps resource envelope', () {
    final result = AgentResultEnvelope.resourceEnvelope(
      resourceName: 'app_errors',
      snapshot: const <String, Object?>{'count': 0},
    );
    final read = agentResultToReadResourceResult(
      result,
      uri: 'visual://localhost/app/errors',
    );
    expect(read.contents, isNotEmpty);
    expect(read.contents.first, isA<TextResourceContents>());
  });

  test(
    'readResourceResultToAgentResult round-trips via agentResultToReadResourceResult',
    () {
      const uri = 'visual://localhost/app/errors';
      final original = ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: uri,
            mimeType: 'application/json',
            text: '{"count":1}',
          ),
        ],
      );
      final agent = readResourceResultToAgentResult(original);
      expect(agent.ok, isTrue);

      final roundTrip = agentResultToReadResourceResult(agent, uri: uri);
      expect(roundTrip.contents, hasLength(1));
      final text = (roundTrip.contents.first as TextResourceContents).text;
      expect(text, '{"count":1}');
    },
  );

  test('agentResultToReadResourceResult maps failure', () {
    final read = agentResultToReadResourceResult(
      AgentResult.failure(code: 'x', message: 'failed'),
      uri: 'test://uri',
    );
    final contents = read.contents.first as TextResourceContents;
    expect(contents.text, contains('failed'));
  });
}
