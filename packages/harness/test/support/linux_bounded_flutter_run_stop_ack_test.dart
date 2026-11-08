@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:test/test.dart';

import 'linux_bounded_flutter_run.dart';

String _machineFakeScript({required String stopMode}) {
  return '''
#!/bin/sh
APP_ID="fake_linux_app"
WS='ws://127.0.0.1:43981/ws'
STOP_MODE="$stopMode"
echo '[{"event":"daemon.connected","params":{"version":"fake","pid":'"\$\$"'}]'
echo '[{"event":"app.start","params":{"appId":"'\$APP_ID'","deviceId":"linux"}}]'
echo '[{"event":"app.debugPort","params":{"appId":"'\$APP_ID'","wsUri":"'\$WS'"}}]'
while IFS= read -r line; do
  case "\$line" in
    *app.stop*)
      id=\$(printf '%s' "\$line" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p' | head -n1)
      [ -z "\$id" ] && id=1
      case "\$STOP_MODE" in
        delayed) sleep 0.25 ;;
        event)
          echo '[{"event":"app.stop","params":{"appId":"'\$APP_ID'"}}]'
          continue
          ;;
        none|exit) exit 0 ;;
      esac
      echo "[{\\"id\\":\$id,\\"result\\":{}}]"
      ;;
  esac
done
exit 0
''';
}

Future<String> _installFakeFlutter(Directory dir, String stopMode) async {
  final path = '${dir.path}/fake_flutter_machine.sh';
  final file = File(path)..writeAsStringSync(_machineFakeScript(stopMode: stopMode));
  await Process.run('chmod', ['+x', path]);
  return path;
}

void main() {
  test(
    'app.stop id response is acknowledged before handle close',
    () async {
      final dir = Directory.systemTemp.createTempSync('linux_stop_ack_');
      final flutterBin = await _installFakeFlutter(dir, 'immediate');
      final target = LinuxBoundedFlutterRunTarget(
        projectDir: dir.path,
        flutterBin: flutterBin,
        vmServiceTimeout: const Duration(seconds: 5),
        stopGrace: const Duration(seconds: 3),
      );
      final app = await target.launch();
      final exit = await app.stop();
      final settlement = target.lastSettlement;
      expect(settlement, isNotNull);
      expect(settlement!.physicallySettled, isTrue);
      expect(settlement.appStopAcknowledged, isTrue);
      expect(settlement.shutdownTruthful, isTrue);
      expect(settlement.cooperativeAckGap, isFalse);
      expect(exit, 0);
    },
    skip: !Platform.isLinux ? 'Linux-only' : null,
  );

  test(
    'app.stop event without id response is acknowledged',
    () async {
      final dir = Directory.systemTemp.createTempSync('linux_stop_event_');
      final flutterBin = await _installFakeFlutter(dir, 'event');
      final target = LinuxBoundedFlutterRunTarget(
        projectDir: dir.path,
        flutterBin: flutterBin,
        vmServiceTimeout: const Duration(seconds: 5),
        stopGrace: const Duration(seconds: 3),
      );
      final app = await target.launch();
      await app.stop();
      final settlement = target.lastSettlement!;
      expect(settlement.appStopAcknowledged, isTrue);
      expect(settlement.shutdownTruthful, isTrue);
    },
    skip: !Platform.isLinux ? 'Linux-only' : null,
  );

  test(
    'exit without app.stop ack is physically settled with documented gap',
    () async {
      final dir = Directory.systemTemp.createTempSync('linux_stop_noack_');
      final flutterBin = await _installFakeFlutter(dir, 'exit');
      final target = LinuxBoundedFlutterRunTarget(
        projectDir: dir.path,
        flutterBin: flutterBin,
        vmServiceTimeout: const Duration(seconds: 5),
        stopGrace: const Duration(milliseconds: 300),
      );
      final app = await target.launch();
      await app.stop();
      final settlement = target.lastSettlement!;
      expect(settlement.physicallySettled, isTrue);
      expect(settlement.appStopAcknowledged, isFalse);
      expect(settlement.cooperativeAckGap, isTrue);
      expect(settlement.shutdownTruthful, isTrue);
    },
    skip: !Platform.isLinux ? 'Linux-only' : null,
  );
}
