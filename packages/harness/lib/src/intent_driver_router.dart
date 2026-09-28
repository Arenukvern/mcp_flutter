import 'package:intentcall_core/intentcall_core.dart';
import 'package:universal_automation_interface/universal_automation_interface.dart';

/// Routes intent automation hints to driver actions — ADR 0038's
/// "invocation can route to a driver action".
///
/// The [IntentAutomationHint] on a registered intent states the transport
/// (`hint.driver`), the verb (`hint.action`), and the locator; this router
/// owns the mapping from that declaration to a concrete
/// [AutomationAction] on the [AutomationDriver] bound under the matching
/// transport name. IntentCall never drives; the consumer that binds
/// drivers decides which transports exist.
///
/// Operands that belong to the *invocation* rather than the registration
/// (the text to type, the route to open, the expression to evaluate)
/// arrive in [arguments] under conventional keys: `text`, `route`, `key`,
/// `expression`. Locator-driven verbs take their element from the hint.
final class IntentDriverRouter {
  /// Creates a router over [drivers], keyed by transport name — the same
  /// names hints use (`toolkit`, `cdp`, `ax`, …).
  IntentDriverRouter({required final Map<String, AutomationDriver> drivers})
    : _drivers = Map.of(drivers);

  final Map<String, AutomationDriver> _drivers;

  /// The bound transports; unmodifiable view.
  Map<String, AutomationDriver> get drivers =>
      Map.unmodifiable(_drivers);

  /// Binds [driver] under [transport] (later bindings win).
  void bind(final String transport, final AutomationDriver driver) {
    _drivers[transport] = driver;
  }

  /// Removes the binding under [transport]. Idempotent.
  void unbind(final String transport) {
    _drivers.remove(transport);
  }

  /// The driver a [hint] names; throws [DriverUnsupportedException] when
  /// the transport is not bound.
  AutomationDriver driverFor(final IntentAutomationHint hint) {
    final driver = _drivers[hint.driver];
    if (driver == null) {
      throw DriverUnsupportedException(
        'no automation driver bound for transport "${hint.driver}"; bound: '
        '${_drivers.keys.join(', ')}',
      );
    }
    return driver;
  }

  /// Resolves [hint] (plus invocation [arguments]) into the concrete
  /// driver action.
  AutomationAction resolve(
    final IntentAutomationHint hint, {
    final Map<String, Object?> arguments = const {},
  }) {
    final locator = hint.locator;
    final operand = switch (hint.action) {
      IntentAutomationAction.click => null,
      IntentAutomationAction.type => arguments['text'],
      IntentAutomationAction.key => arguments['key'],
      IntentAutomationAction.navigate => arguments['route'] ?? arguments['to'],
      IntentAutomationAction.evaluate => arguments['expression'],
    };
    final element =
        locator['css'] ?? locator['ref'] ?? locator['name'] ??
        locator['role'];
    return switch (hint.action) {
      // Locator priority follows the ToolkitDriver grammar: exact
      // ref/label first, then role; the name locator doubles as a label
      // for drivers whose snapshot exposes names.
      IntentAutomationAction.click => ClickAction(
        css: locator['css'] ?? locator['ref'],
        role: locator['role'],
        name: locator['name'],
      ),
      IntentAutomationAction.type => TypeAction(
        (operand ?? locator['value'] ?? '').toString(),
        css: element,
      ),
      IntentAutomationAction.key => KeyPressAction(
        (operand ?? locator['key'] ?? '').toString(),
      ),
      IntentAutomationAction.navigate => NavigateAction(
        Uri.parse((operand ?? locator['route'] ?? '/').toString()),
      ),
      IntentAutomationAction.evaluate => EvaluateAction(
        (operand ?? '').toString(),
      ),
    };
  }

  /// Resolves [hint] and performs it on the named driver. Returns the
  /// driver that executed the action.
  Future<AutomationDriver> invoke(
    final IntentAutomationHint hint, {
    final Map<String, Object?> arguments = const {},
  }) async {
    final driver = driverFor(hint);
    await driver.perform(resolve(hint, arguments: arguments));
    return driver;
  }

  /// Convenience for a registered intent: routes [intent]'s automation
  /// hint. Throws [DriverUnsupportedException] when the intent declares
  /// no hint — an intent without one is not driver-routable.
  Future<AutomationDriver> invokeIntent(
    final RegisteredAgentIntent intent, {
    final Map<String, Object?> arguments = const {},
  }) {
    final hint = intent.descriptor.automation;
    if (hint == null) {
      throw const DriverUnsupportedException(
        'intent declares no automation hint; it is not driver-routable',
      );
    }
    return invoke(hint, arguments: arguments);
  }
}
