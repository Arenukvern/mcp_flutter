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

  test('agentResultToReadResourceResult maps failure', () {
    final read = agentResultToReadResourceResult(
      AgentResult.failure(code: 'x', message: 'failed'),
      uri: 'test://uri',
    );
    final text = (read.contents.first as TextResourceContents).text!;
    expect(text, contains('failed'));
  });
}
