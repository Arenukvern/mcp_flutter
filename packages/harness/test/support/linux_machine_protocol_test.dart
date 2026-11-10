@TestOn('vm')
library;

import 'package:test/test.dart';

import 'linux_machine_protocol.dart';

void main() {
  test('unwraps id response array line', () {
    final map = unwrapFlutterMachineLine('[{"id":2,"result":{}}]');
    expect(map?['id'], 2);
    expect(
      machineAppStopAckFromPayload(
        map!,
        stopRequestId: 2,
      ),
      isTrue,
    );
  });

  test('accepts app.stop event without request id', () {
    final map = unwrapFlutterMachineLine(
      '[{"event":"app.stop","params":{"appId":"my_app"}}]',
    );
    expect(map, isNotNull);
    expect(
      machineAppStopAckFromPayload(
        map!,
        stopRequestId: 99,
        expectedAppId: 'my_app',
      ),
      isTrue,
    );
  });

  test('rejects app.stop event for wrong appId', () {
    final map = unwrapFlutterMachineLine(
      '[{"event":"app.stop","params":{"appId":"other"}}]',
    );
    expect(
      machineAppStopAckFromPayload(
        map!,
        stopRequestId: 1,
        expectedAppId: 'my_app',
      ),
      isNull,
    );
  });

  test('error response is explicit nack', () {
    expect(
      machineAppStopAckFromLine(
        '[{"id":1,"error":"boom"}]',
        stopRequestId: 1,
      ),
      isFalse,
    );
  });
}
