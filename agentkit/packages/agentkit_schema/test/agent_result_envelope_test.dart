import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:test/test.dart';

void main() {
  test('resourceEnvelope builds visual uri', () {
    final result = AgentResultEnvelope.resourceEnvelope(
      resourceName: 'spark_runtime_snapshot',
      snapshot: {'phase': 'playing'},
    );
    expect(result.ok, isTrue);
    expect(
      result.data['resource_uri'],
      'visual://localhost/spark/runtime/snapshot',
    );
  });
}
