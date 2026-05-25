import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:test/test.dart';

void main() {
  test('parses bool and int from wire strings', () {
    const wire = AgentWireArgs({'strictEnabled': 'true', 'count': '42'});
    expect(wire.bool_('strictEnabled'), isTrue);
    expect(wire.int_('count'), 42);
  });
}
