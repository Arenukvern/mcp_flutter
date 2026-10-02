import 'dart:convert';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:test/test.dart';
import 'package:universal_automation_conformance/universal_automation_conformance.dart';
import 'package:universal_automation_interface/universal_automation_interface.dart';

/// Canned flat wire snapshot: ref-linked nodes exactly as
/// `ext.mcp.toolkit.semantic_snapshot` emits them (bounds are
/// left/top/right/bottom; `children` holds refs).
Map<String, dynamic> _snapshotEnvelope() => {
  'snapshot_id': 41,
  'nodes': [
    {'ref': 's_0', 'type': 'widget', 'children': ['s_1', 's_2', 's_3', 's_4']},
    {'ref': 's_1', 'type': 'text', 'label': 'Counter: 0'},
    {
      'ref': 's_2',
      'type': 'button',
      'label': 'Increment',
      'bounds': {'left': 10.0, 'top': 20.0, 'right': 110.0, 'bottom': 60.0},
    },
    {
      'ref': 's_3',
      'type': 'textField',
      'label': 'Name',
      'value': '',
      'bounds': {'left': 0.0, 'top': 80.0, 'right': 200.0, 'bottom': 120.0},
    },
    {'ref': 's_4', 'type': 'header', 'label': 'Section'},
  ],
};

const String _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhf'
    'DwAChwGA60e6kgAAAABJRU5ErkJggg==';

/// Extension-call seam with per-verb canned answers and a call log.
(ExtensionCall call, List<String> log) _fakeApp() {
  final log = <String>[];
  Future<Map<String, dynamic>> call(
    final String name, {
    final Map<String, Object?> args = const {},
  }) async {
    log.add('$name $args');
    return switch (name) {
      ToolkitExtensions.snapshot => _snapshotEnvelope(),
      ToolkitExtensions.viewScreenshots => {
        'images': [_pngBase64],
      },
      ToolkitExtensions.navigate => args['route'] == '/settings'
          ? {'success': true, 'action': 'push'}
          : {
            'success': false,
            'error': 'route_not_found',
            'action': 'push',
            'hint': 'unknown name',
          },
      ToolkitExtensions.pressKey =>
        args['key'] == 'Enter'
            ? {'success': true}
            : {
              'success': false,
              'error': 'unknown_key',
              'acceptedNames': ['Enter', 'Escape', 'Tab'],
            },
      ToolkitExtensions.scroll => args['direction'] == 'left'
          ? {
            'success': false,
            'error': 'invalid_direction',
            'hint': 'use up, down',
          }
          : {'success': true},
      ToolkitExtensions.agentCatalog => {
        'success': true,
        'actions': [
          {
            'name': 'app.buy_item',
            'namespace': 'app',
            'description': 'Buys an item',
            'inputSchema': {
              'type': 'object',
              'required': ['sku'],
              'properties': {'sku': {'type': 'string'}},
            },
          },
          {'name': 'reset_state', 'namespace': 'app', 'description': ''},
        ],
      },
      ToolkitExtensions.agentInvoke =>
        args['name'] == 'unknown_op'
            ? {
              'success': false,
              'error': 'unknown registry action: unknown_op',
            }
            : {
              'success': true,
              'result': {'orderId': 'o-1'},
            },
      _ => {'success': true},
    };
  }

  return (call, log);
}

void main() {
  group('ToolkitDriver (canned extension responses)', () {
    test('snapshot nests the flat ref-linked wire into a semantic tree',
        () async {
      final driver = ToolkitDriver.custom(_fakeApp().$1);
      final snapshot = await driver.snapshot();
      expect(snapshot.revision, 41);
      expect(snapshot.roots, hasLength(1));
      final root = snapshot.roots.single;
      expect(root.role, 'generic');
      expect(root.children.map((node) => node.role), [
        'text',
        'button',
        'textbox',
        'heading',
      ]);
      final button = root.children[1];
      expect(button.attributes['ref'], 's_2');
      expect(button.bounds!.width, 100.0);
      expect(button.bounds!.height, 40.0);
      expect(button.bounds!.center, (60.0, 40.0));
      await driver.close();
    });

    test('click resolves name, css ref, and css label locators', () async {
      final (call, log) = _fakeApp();
      final driver = ToolkitDriver.custom(call);
      await driver.perform(const ClickAction(name: 'increment'));
      await driver.perform(const ClickAction(css: 's_2'));
      await driver.perform(const ClickAction(css: 'INCREM'));
      final taps = log.where((line) => line.startsWith('ext.mcp.toolkit.tap'));
      expect(taps, hasLength(3));
      expect(taps.every((line) => line.contains('s_2')), isTrue);
      await driver.close();
    });

    test('click resolves role with name disambiguation', () async {
      final (call, _) = _fakeApp();
      final driver = ToolkitDriver.custom(call);
      await driver.perform(const ClickAction(role: 'textbox', name: 'Name'));
      await driver.close();
    });

    test('click on a missing element refuses with the locator identity',
        () async {
      final driver = ToolkitDriver.custom(_fakeApp().$1);
      await expectLater(
        driver.perform(const ClickAction(name: 'nonexistent')),
        throwsA(
          isA<ElementNotFoundException>()
              .having((error) => error.kind, 'kind', 'elementNotFound')
              .having((error) => error.locator, 'locator', 'name'),
        ),
      );
      await driver.close();
    });

    test('type enters text through the resolved ref and submits', () async {
      final (call, log) = _fakeApp();
      final driver = ToolkitDriver.custom(call);
      await driver.perform(
        const TypeAction('Ada', css: 'Name', submit: true),
      );
      expect(
        log.any(
          (line) => line.contains('enter_text') && line.contains('s_3'),
        ),
        isTrue,
      );
      expect(
        log.any((line) => line.contains('press_key') && line.contains('Enter')),
        isTrue,
      );
      await driver.close();
    });

    test('type without a locator refuses loudly', () async {
      final driver = ToolkitDriver.custom(_fakeApp().$1);
      await expectLater(
        driver.perform(const TypeAction('Ada')),
        throwsA(isA<DriverUnsupportedException>()),
      );
      await driver.close();
    });

    test('navigate pushes named routes and refuses unknown ones', () async {
      final (call, log) = _fakeApp();
      final driver = ToolkitDriver.custom(call);
      await driver.perform(NavigateAction(Uri.parse('/settings')));
      expect(
        log.any((line) => line.contains('navigate') && line.contains('/settings')),
        isTrue,
      );
      await expectLater(
        driver.perform(NavigateAction(Uri.parse('about:blank#nope'))),
        throwsA(
          isA<DriverUnsupportedException>().having(
            (error) => error.message,
            'message',
            contains('not a registered named route'),
          ),
        ),
      );
      await driver.close();
    });

    test('scroll maps direction and distance through the extension',
        () async {
      final (call, log) = _fakeApp();
      final driver = ToolkitDriver.custom(call);
      await driver.perform(
        const ScrollAction(direction: 'Down', distance: 420),
      );
      expect(
        log.any(
          (line) => line.contains('ext.mcp.toolkit.scroll') &&
              line.contains('down') &&
              line.contains('420.0'),
        ),
        isTrue,
      );
      // In-band refusal surfaces as a protocol error, not silence.
      await expectLater(
        driver.perform(const ScrollAction(direction: 'left')),
        throwsA(
          isA<ProtocolException>().having(
            (error) => error.message,
            'message',
            contains('invalid_direction'),
          ),
        ),
      );
      await driver.close();
    });

    test('unknown keys surface the accepted names', () async {
      final driver = ToolkitDriver.custom(_fakeApp().$1);
      await expectLater(
        driver.perform(const KeyPressAction('F13')),
        throwsA(
          isA<ProtocolException>().having(
            (error) => error.message,
            'message',
            contains('Enter, Escape, Tab'),
          ),
        ),
      );
      await driver.close();
    });

    test('screenshot decodes the main view PNG', () async {
      final driver = ToolkitDriver.custom(_fakeApp().$1);
      final bytes = await driver.screenshot();
      expect(bytes, base64Decode(_pngBase64));
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);
      await driver.close();
    });

    test('capabilities stay honest about the evaluator', () async {
      expect(
        ToolkitDriver.custom(_fakeApp().$1).capabilities.evaluate,
        isFalse,
      );
      expect(
        ToolkitDriver.custom(_fakeApp().$1, evaluate: (_) async => 'x')
            .capabilities
            .evaluate,
        isTrue,
      );
    });

    test('methods throw after close; close is idempotent', () async {
      final driver = ToolkitDriver.custom(_fakeApp().$1);
      await driver.close();
      await driver.close();
      expect(driver.snapshot, throwsStateError);
    });
  });

  group('invoke tier (ADR-0017 — the registry is the action source)', () {
    test('actions() lists the app registry as descriptors', () async {
      final (call, _) = _fakeApp();
      final driver = ToolkitDriver.custom(call);
      final actions = await driver.actions();
      expect(actions, hasLength(2));
      expect(actions[0].name, 'app.buy_item');
      expect(actions[0].description, 'Buys an item');
      expect(
        actions[0].inputSchema?['required'],
        ['sku'],
      );
      expect(actions[1].inputSchema, isNull);
    });

    test('InvokeAction validates against the schema then dispatches',
        () async {
      final (call, log) = _fakeApp();
      final driver = ToolkitDriver.custom(call);
      await driver.perform(
        InvokeAction('app.buy_item', args: {'sku': 'x-1'}),
      );
      // Observe (catalog) before act (invoke); args ride JSON-encoded.
      expect(log, hasLength(2));
      expect(log[0], contains('agent_catalog'));
      expect(log[1], contains('agent_invoke'));
      expect(log[1], contains('"sku":"x-1"'));
    });

    test('schema violations fail on this side of the wire', () async {
      final (call, log) = _fakeApp();
      final driver = ToolkitDriver.custom(call);
      await expectLater(
        driver.perform(const InvokeAction('app.buy_item', args: {})),
        throwsA(isA<AgentValidationException>()),
      );
      // Catalog was read, but the bad args never reached the app.
      expect(log.where((entry) => entry.contains('agent_invoke')), isEmpty);
    });

    test('unknown names dispatch — the app refusal is authoritative',
        () async {
      final (call, _) = _fakeApp();
      final driver = ToolkitDriver.custom(call);
      await expectLater(
        driver.perform(const InvokeAction('unknown_op')),
        throwsA(
          isA<ProtocolException>().having(
            (e) => e.message,
            'message',
            contains('unknown registry action: unknown_op'),
          ),
        ),
      );
    });
  });

  automationDriverConformanceTests(
    'ToolkitDriver',
    createDriver: () async {
      final (call, _) = _fakeApp();
      return ToolkitDriver.custom(call, evaluate: (_) async => 'null');
    },
  );
}
