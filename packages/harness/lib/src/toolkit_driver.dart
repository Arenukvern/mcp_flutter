import 'dart:convert';
import 'dart:typed_data';

import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:universal_automation_interface/universal_automation_interface.dart';
import 'package:vm_service/vm_service.dart' show RPCError;

import 'toolkit_extensions.dart';
import 'vm_client.dart';

/// Call signature of one VM service extension invocation. The seam tests
/// use to answer with canned envelopes instead of a live VM.
typedef ExtensionCall =
    Future<Map<String, dynamic>> Function(
      String name, {
      Map<String, Object?> args,
    });

/// [AutomationDriver] over the MCP toolkit's VM-service extensions —
/// the instrumented tier of the `universal_automation_*` family (ADR 0038).
///
/// One observe/act/verify loop for the Flutter app the toolkit is bound
/// to, in the same vocabulary as the CDP, WebDriver, and OS-native
/// drivers: agents no longer learn a second grammar to drive a Flutter
/// app. The toolkit's MCP tools and CLI stay thin transports over the
/// same extensions; this driver is the engine face.
///
/// Locator grammar (the instrumented tier has no CSS):
/// - `css` — a snapshot ref from the latest [snapshot] (`"s_12"`), or a
///   label substring; refs are the stable instrumented element ids.
/// - `name` — first node whose label contains it (case-insensitive).
/// - `role` — first node whose semantic role matches (`button`,
///   `textbox`, …); [ClickAction.name] disambiguates.
///
/// Navigation surface: the toolkit's *named routes* ([NavigateAction]'s
/// path becomes the route name). A URL that is not a registered route is
/// refused loudly ([DriverUnsupportedException]) — this driver never
/// pretends to be a browser.
///
/// Connection ownership: [close] releases the driver, not the
/// [VmClient] — the harness target that launched the app keeps owning
/// the process and its VM service.
///
/// Surface actions ([InvokeAction]) read the app's agent-call registry —
/// the intent registry is the single action source (ADR-0017), so an
/// intent registered once is drivable here, an MCP tool, and a
/// projection. [actions] lists the registry; [InvokeAction] dispatch
/// validates arguments against each action's declared schema
/// (`intentcall_schema`) before the wire, so bad arguments fail on this
/// side with an actionable message.
final class ToolkitDriver
    implements AutomationDriver, AutomationActionCatalog {
  /// Drives the app behind [client].
  ToolkitDriver(final VmClient client)
    : this.custom(client.callExtension, evaluate: client.evaluate);

  /// Drives through a custom [ExtensionCall] (tests, alternate
  /// transports). [evaluate] backs [EvaluateAction]; omitting it keeps
  /// the `evaluate` capability honest by refusing evaluation.
  ToolkitDriver.custom(final ExtensionCall call, {this.evaluate})
    : _call = call;

  final ExtensionCall _call;

  /// Read-only expression evaluator (root-library context of the app's
  /// main isolate). The contract's [EvaluateAction] discards results —
  /// for values, prefer [snapshot] or [VmClient.evaluate] directly.
  final Future<String> Function(String expression)? evaluate;

  bool _closed = false;
  int _revision = 0;

  @override
  DriverCapabilities get capabilities => DriverCapabilities(
    attach: true,
    screenshot: true,
    // Continuous frames are a frame-source concern, not a driving
    // concern: adapters (family-owned universal_capture_flutter, or a
    // consumer-owned one) poll [ToolkitExtensions.viewScreenshots]
    // themselves. This package stays pipeline-free.
    screencast: false,
    a11yTree: true,
    inputSynthesis: true,
    evaluate: evaluate != null,
  );

  @override
  Future<Snapshot> snapshot() async {
    _ensureOpen();
    final raw = await _call(ToolkitExtensions.snapshot);
    final data = _unwrap(raw);
    _revision = (data['snapshot_id'] as num?)?.toInt() ?? _revision;
    final flat = <String, Map<String, Object?>>{
      for (final node in (data['nodes'] as List<Object?>? ?? const []))
        if (node is Map && node['ref'] is String)
          node['ref']! as String: _stringMap(node),
    };
    // The wire is flat; `children` holds refs. Nodes nobody links to are
    // the roots — nesting under them rebuilds the tree.
    final linked = <String>{
      for (final node in flat.values)
        ...(node['children'] as List<Object?>? ?? const []).whereType<String>(),
    };
    return Snapshot(
      roots: [
        for (final entry in flat.entries)
          if (!linked.contains(entry.key))
            _axNode(entry.key, entry.value, flat),
      ],
      capturedAt: DateTime.now().toUtc(),
      revision: _revision,
    );
  }

  @override
  Future<void> perform(final AutomationAction action) async {
    _ensureOpen();
    switch (action) {
      case NavigateAction(:final url):
        await _navigate(url);
      case ClickAction(:final css, :final role, :final name):
        final ref = await _resolveRef(css: css, role: role, name: name);
        await _call(ToolkitExtensions.tap, args: {'ref': ref});
      case TypeAction(:final text, :final css, :final submit):
        if (css == null) {
          throw const DriverUnsupportedException(
            'ToolkitDriver.type needs a locator (css = ref or label); '
            'the instrumented tier does not type into "whatever is '
            'focused"',
          );
        }
        final ref = await _resolveRef(css: css);
        await _call(
          ToolkitExtensions.enterText,
          args: {'ref': ref, 'text': text},
        );
        if (submit) await _pressKey('Enter');
      case KeyPressAction(:final key):
        await _pressKey(key);
      case ScrollAction(:final direction, :final distance):
        final raw = _unwrap(
          await _call(
            ToolkitExtensions.scroll,
            args: {
              'direction': direction.toLowerCase(),
              'distance': ?distance,
            },
          ),
        );
        if (raw['success'] == false) {
          throw ProtocolException(
            'scroll refused: ${raw['error']} — ${raw['hint'] ?? 'no hint'}',
          );
        }
      case EvaluateAction(:final expression):
        final evaluator = evaluate;
        if (evaluator == null) {
          throw const DriverUnsupportedException(
            'ToolkitDriver was built without an evaluator; evaluate is '
            'not available on this transport',
          );
        }
        await evaluator(expression);
      case InvokeAction(:final name, :final args):
        await _invokeRegistryAction(name, args);
    }
  }

  @override
  Future<List<SurfaceActionDescriptor>> actions() async {
    _ensureOpen();
    final data = _unwrap(await _call(ToolkitExtensions.agentCatalog));
    final actions = data['actions'];
    return [
      if (actions is List)
        for (final entry in actions)
          ?SurfaceActionDescriptor.fromJson(entry),
    ];
  }

  /// Validates [args] against the registry action's declared schema and
  /// dispatches through `agent_invoke`.
  ///
  /// An unknown name still dispatches: the app side owns the registry and
  /// may have grown since the catalog read — its refusal is authoritative.
  Future<void> _invokeRegistryAction(
    final String name,
    final Map<String, Object?> args,
  ) async {
    _ensureOpen();
    for (final action in await actions()) {
      if (action.name == name) {
        final schema = action.inputSchema;
        if (schema != null) {
          validateAgainstSchema(schema, args);
        }
        break;
      }
    }
    final raw = _unwrap(
      await _call(
        ToolkitExtensions.agentInvoke,
        args: {'name': name, 'json': jsonEncode(args)},
      ),
    );
    if (raw['success'] == false) {
      throw ProtocolException(
        'invoke "$name" refused: ${raw['error'] ?? 'no reason given'}',
      );
    }
  }

  @override
  Future<Uint8List> screenshot() async {
    _ensureOpen();
    final raw = await _call(
      ToolkitExtensions.viewScreenshots,
      args: {'compress': false},
    );
    final images = (_unwrap(raw)['images'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toList();
    if (images.isEmpty) {
      throw const ProtocolException('view_screenshots returned no images');
    }
    // Multi-view apps list every view; the first is the main one.
    return base64Decode(images.first);
  }

  @override
  Future<void> close() async {
    _closed = true;
  }

  Future<void> _navigate(final Uri url) async {
    final route = url.path.isEmpty ? url.toString() : url.path;
    final Map<String, Object?> raw;
    try {
      raw = await _call(
        ToolkitExtensions.navigate,
        args: {'action': 'push', 'route': route},
      );
    } on RPCError catch (error) {
      throw DriverUnsupportedException(
        'ToolkitDriver refuses navigation to "$url": the app rejected '
        'route "$route" (${error.code})',
      );
    }
    if (_unwrap(raw)['success'] == false) {
      final error = _unwrap(raw)['error'];
      throw DriverUnsupportedException(
        'ToolkitDriver refuses navigation to "$url": route "$route" is '
        'not a registered named route of this app${error == null ? '' : ' ($error)'}',
      );
    }
  }

  /// Resolves [ClickAction]/[TypeAction] locators against a fresh
  /// snapshot — refs are only meaningful per snapshot, so every act
  /// observes first. Order: exact ref, label substring, role.
  Future<String> _resolveRef({
    final String? css,
    final String? role,
    final String? name,
  }) async {
    if (css == null && role == null && name == null) {
      throw const DriverUnsupportedException(
        'ToolkitDriver needs a locator: css (ref or label), name, or role',
      );
    }
    final nodes = (await snapshot()).nodes.toList();
    if (css != null) {
      for (final node in nodes) {
        final candidate = node.attributes['ref'];
        if (candidate != null && candidate == css) return candidate;
      }
      for (final node in nodes) {
        final label = node.name;
        final ref = node.attributes['ref'];
        if (label != null &&
            ref != null &&
            label.toLowerCase().contains(css.toLowerCase())) {
          return ref;
        }
      }
      throw ElementNotFoundException('css', css);
    }
    if (name != null || role != null) {
      // Role and name compose: `role: 'textbox', name: 'Confirm'` must
      // not degrade to name-only matching and click a button that
      // happens to be labeled Confirm.
      for (final node in nodes) {
        final label = node.name;
        final ref = node.attributes['ref'];
        final roleOk = role == null || node.role == role;
        final nameOk = name == null ||
            (label != null &&
                label.toLowerCase().contains(name.toLowerCase()));
        if (ref != null && roleOk && nameOk) return ref;
      }
      throw ElementNotFoundException(
        role != null ? 'role' : 'name',
        role ?? name!,
      );
    }
    throw const DriverUnsupportedException(
      'ToolkitDriver needs a locator: css (ref or label), name, or role',
    );
  }

  Future<void> _pressKey(final String key) async {
    final raw = _unwrap(
      await _call(ToolkitExtensions.pressKey, args: {'key': key}),
    );
    if (raw['success'] == false) {
      throw ProtocolException(
        'press_key rejected "$key": ${raw['error']} — accepted names: '
        '${raw['acceptedNames'] ?? 'single characters'}',
      );
    }
  }

  /// Nests the flat ref-linked wire nodes into [AxNode]s.
  AxNode _axNode(
    final String ref,
    final Map<String, Object?> wire,
    final Map<String, Map<String, Object?>> flat,
  ) {
    final type = wire['type'] as String?;
    final identifier = wire['identifier'] as String?;
    final bounds = wire['bounds'];
    return AxNode(
      role: _role(type),
      name: (wire['label'] as String?) ?? identifier,
      value: wire['value'] as String?,
      bounds: bounds is Map
          ? AxBounds(
              left: (bounds['left'] as num).toDouble(),
              top: (bounds['top'] as num).toDouble(),
              width: ((bounds['right'] as num) - (bounds['left'] as num))
                  .toDouble(),
              height: ((bounds['bottom'] as num) - (bounds['top'] as num))
                  .toDouble(),
            )
          : null,
      attributes: {
        'ref': ref,
        'type': ?type,
        'identifier': ?identifier,
        if (wire['enabled'] is bool) 'enabled': '${wire['enabled']}',
      },
      children: [
        for (final childRef
            in (wire['children'] as List<Object?>? ?? const [])
                .whereType<String>())
          if (flat[childRef] case final child?) _axNode(childRef, child, flat),
      ],
    );
  }

  /// Maps the toolkit's node classifier onto the family's lowercase
  /// protocol-agnostic roles; the raw type stays in `attributes.type`.
  static String _role(final String? type) => switch (type) {
    'textField' => 'textbox',
    'header' => 'heading',
    'tappable' || 'longPressable' || 'widget' || null => 'generic',
    _ => type.toLowerCase(),
  };

  Map<String, Object?> _unwrap(final Map<String, dynamic> raw) =>
      (raw['data'] ?? raw) as Map<String, Object?>;

  Map<String, Object?> _stringMap(final Map<Object?, Object?> raw) => {
    for (final entry in raw.entries)
      if (entry.key is String) entry.key! as String: entry.value,
  };

  void _ensureOpen() {
    if (_closed) {
      throw StateError('ToolkitDriver is closed');
    }
  }
}
