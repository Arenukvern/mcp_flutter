import 'dart:typed_data';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';
import 'package:universal_automation_interface/universal_automation_interface.dart';

/// Records performed actions; capabilities stay honest (nothing declared).
final class _RecordingDriver implements AutomationDriver {
  final actions = <AutomationAction>[];

  @override
  DriverCapabilities get capabilities => const DriverCapabilities(
    a11yTree: true,
    inputSynthesis: true,
    evaluate: true,
  );

  @override
  Future<void> perform(final AutomationAction action) async {
    actions.add(action);
  }

  @override
  Future<Snapshot> snapshot() => Future.value(
    Snapshot(
      roots: const [],
      capturedAt: DateTime.now().toUtc(),
      revision: 0,
    ),
  );

  @override
  Future<Uint8List> screenshot() => Future.value(Uint8List(0));

  @override
  Future<void> close() async {}
}

void main() {
  group('IntentDriverRouter', () {
    late _RecordingDriver toolkit;
    late IntentDriverRouter router;

    setUp(() {
      toolkit = _RecordingDriver();
      router = IntentDriverRouter(drivers: {'toolkit': toolkit});
    });

    test('click hints resolve every locator variant', () async {
      await router.invoke(
        IntentAutomationHint(
          driver: 'toolkit',
          locator: const {'name': 'Buy'},
        ),
      );
      await router.invoke(
        IntentAutomationHint(
          driver: 'toolkit',
          locator: const {'ref': 's_12'},
        ),
      );
      await router.invoke(
        IntentAutomationHint(
          driver: 'toolkit',
          locator: const {'role': 'button', 'name': 'Buy'},
        ),
      );
      expect(toolkit.actions, hasLength(3));
      final first = toolkit.actions[0] as ClickAction;
      expect(first.name, 'Buy');
      // ClickAction is a value without operator== — compare fields.
      expect((toolkit.actions[1] as ClickAction).css, 's_12');
      final third = toolkit.actions[2] as ClickAction;
      expect(third.role, 'button');
      expect(third.name, 'Buy');
    });

    test('type/key/navigate/evaluate take invocation operands', () async {
      await router.invoke(
        IntentAutomationHint(
          driver: 'toolkit',
          action: IntentAutomationAction.type,
          locator: const {'name': 'Name'},
        ),
        arguments: const {'text': 'Ada'},
      );
      await router.invoke(
        IntentAutomationHint(
          driver: 'toolkit',
          action: IntentAutomationAction.key,
          locator: const {'key': 'Enter'},
        ),
      );
      await router.invoke(
        IntentAutomationHint(
          driver: 'toolkit',
          action: IntentAutomationAction.navigate,
        ),
        arguments: const {'route': '/profile'},
      );
      await router.invoke(
        IntentAutomationHint(
          driver: 'toolkit',
          action: IntentAutomationAction.evaluate,
        ),
        arguments: const {'expression': '1 + 1'},
      );

      expect((toolkit.actions[0] as TypeAction).text, 'Ada');
      expect((toolkit.actions[0] as TypeAction).css, 'Name');
      expect((toolkit.actions[1] as KeyPressAction).key, 'Enter');
      expect(
        (toolkit.actions[2] as NavigateAction).url.toString(),
        '/profile',
      );
      expect((toolkit.actions[3] as EvaluateAction).expression, '1 + 1');
    });

    test('unbound transports refuse loudly and unbind removes', () async {
      expect(
        () => router.invoke(
          IntentAutomationHint(
            driver: 'ax',
            locator: const {'name': 'Buy'},
          ),
        ),
        throwsA(
          isA<DriverUnsupportedException>().having(
            (error) => error.message,
            'message',
            contains('bound: toolkit'),
          ),
        ),
      );
      router.unbind('toolkit');
      expect(router.drivers, isEmpty);
      router.bind('toolkit', toolkit);
      expect(
        router.driverFor(
          IntentAutomationHint(
            driver: 'toolkit',
            locator: const {'name': 'Buy'},
          ),
        ),
        same(toolkit),
      );
    });

    test('invokeIntent refuses intents without a hint', () async {
      final registryIntent = RegisteredAgentIntent(
        descriptor: AgentIntentDescriptor(
          namespace: 'app',
          name: 'plain',
          description: 'no hint',
          kind: AgentIntentKind.tool,
          inputSchema: const {'type': 'object'},
        ),
        execute: (_) async => AgentResult.success(),
      );
      expect(
        () => router.invokeIntent(registryIntent),
        throwsA(isA<DriverUnsupportedException>()),
      );
    });
  });
}
