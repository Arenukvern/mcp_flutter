import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:universal_browser_cdp/universal_browser_cdp.dart';


/// Flutter-web driving techniques over [CdpPage], extracted from the
/// multiplayer gates that proved them against real Chromium. Each one
/// exists because the obvious approach FAILED measurably:
///
/// - Locate by text/aria-label in the LIVE `flt-semantics` DOM and click
///   the bounding-box center: the AX snapshot's `backendDOMNodeId`s go
///   stale on Flutter web (nodes are replaced as semantics update), so
///   snapshot-resolved clicks die with "detached" — the driver's
///   fallback ladder now handles this too, but the *effect-verified*
///   interaction loop lives here.
/// - `first click after load is swallowed` — burn one click on nothing
///   ([warmUpClick]) before real interactions.
/// - State-transition clicks re-click until the EFFECT appears, and
///   check the effect BEFORE re-clicking (a toggle re-click flips it
///   back off — the mesh checkbox measured exactly that).
/// - Typing into a background window: [typeFocused] = bringToFront +
///   `Input.insertText` (per-key events land nowhere without OS focus).
/// - In-app navigation only: a page reload drops in-memory app state
///   ([popRoute]) — hash-route history pops, never reloads.
final class FlutterWebCdp {
  FlutterWebCdp(this.page, this.driver);

  final CdpPage page;
  final CdpDriver driver;

  /// A sacrificial click on the page body — the first pointer event
  /// after load is swallowed by the engine; burn it on nothing.
  Future<void> warmUpClick() async {
    await page.connection.send('Page.bringToFront');
    await page.clickAt(680, 500);
  }

  /// Clicks the LAST `flt-semantics` whose text content or aria-label
  /// CONTAINS [text]; last match wins (overlays/dialogs sit deeper in
  /// the DOM than page chrome; a newer row is newer data).
  Future<void> clickText(
    String text, {
    String? expect,
    int attempts = 10,
    Duration delay = const Duration(seconds: 1),
  }) async {
    for (var i = 1; i <= attempts; i++) {
      // Effect FIRST: a re-click of a toggle flips it back off — only
      // click while the expected state is absent.
      if (expect != null && await hasText(expect)) {
        return;
      }
      final box = await stableRect(text);
      if (box != null) {
        await page.clickAt(box.$1, box.$2);
        if (expect == null) return;
      }
      await Future<void>.delayed(delay);
    }
    throw StateError(
      'clickText never landed "$text"'
      '${expect == null ? '' : ' (effect "$expect" never showed)'}',
    );
  }

  /// A rect that reads the SAME twice, 300ms apart — panels animate open
  /// after a click, and a rect taken mid-animation clicks whatever
  /// widget scrolls under the coordinates.
  Future<(double, double)?> stableRect(String text) async {
    final first = await rectOf(text);
    if (first == null) return null;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final second = await rectOf(text);
    if (second == null) return null;
    const tolerance = 3.0;
    return (first.$1 - second.$1).abs() <= tolerance &&
            (first.$2 - second.$2).abs() <= tolerance
        ? second
        : null;
  }

  /// The bounding-box center of the LAST `flt-semantics` whose text
  /// content or aria-label CONTAINS [text]; null when none is visible.
  Future<(double, double)?> rectOf(String text) async {
    final raw = await page.evaluate(
      '(() => { const els = '
      '[...document.querySelectorAll("flt-semantics")];'
      ' const el = els.reverse().find(e => '
      '(e.textContent || "").includes(${_js(text)}) || '
      '(e.getAttribute("aria-label") || "").includes(${_js(text)}));'
      ' if (!el) return null;'
      ' const b = el.getBoundingClientRect();'
      ' if (b.width < 2 || b.height < 2) return null;'
      ' return JSON.stringify({x: b.x + b.width / 2, '
      'y: b.y + b.height / 2}); })()',
    );
    if (raw is! String || raw.isEmpty) return null;
    final box = jsonDecode(raw) as Map<String, Object?>;
    return ((box['x']! as num).toDouble(), (box['y']! as num).toDouble());
  }

  /// True when the live DOM carries [text] (textContent or aria-label).
  Future<bool> hasText(String text) async => await rectOf(text) != null;

  /// Polls until [text] appears; [TimeoutException] with an AX dump
  /// path hint on exhaustion.
  Future<void> waitText(
    String text, {
    int attempts = 30,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (var i = 1; i <= attempts; i++) {
      if (await hasText(text)) return;
      await Future<void>.delayed(delay);
    }
    throw TimeoutException('page never showed "$text"');
  }

  /// First of [texts] present; polled; null when none appears.
  Future<String?> waitAny(
    List<String> texts, {
    int attempts = 30,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (var i = 1; i <= attempts; i++) {
      for (final text in texts) {
        if (await hasText(text)) return text;
      }
      await Future<void>.delayed(delay);
    }
    return null;
  }

  /// Types into the FOCUSED editable via `Input.insertText` — the
  /// background-window-safe path (per-key events land nowhere without
  /// OS focus; measured).
  Future<void> typeFocused(String text) async {
    await page.connection.send('Page.bringToFront');
    await page.connection.send('Input.insertText', {'text': text});
  }

  /// The LAST `<textarea>`/`<input>` value — the focused dialog field
  /// sits deeper than page fields ("last wins" ordering).
  Future<String?> lastEditableValue() => page.fieldValue(
        'flt-semantics textarea, flt-semantics input',
      );

  /// Pops the top pushed route while [screenMarker] is visible (the
  /// screen's own chrome text). In-app navigation only: a reload drops
  /// in-memory state. Primary: `history.back()` (hash-route history).
  /// Fallback: the leading top-left button + Escape — both need
  /// re-forwarded focus, so the page
  /// is re-forwarded every attempt. Never clicks once the marker is
  /// gone — the underlying screen's leftmost control may be destructive.
  Future<void> popRoute({
    required String screenMarker,
    int attempts = 15,
  }) async {
    for (var i = 1; i <= attempts; i++) {
      if (!await hasText(screenMarker)) return;
      await page.connection.send('Page.bringToFront');
      await page.evaluate('history.back()');
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw StateError('route with marker "$screenMarker" never closed');
  }

  /// Dumps the AX snapshot as JSON into [directory] — the failure
  /// evidence for a missed locator.
  Future<File> dumpAx(Directory directory, String label) async {
    final snap = await driver.snapshot();
    final nodes = [
      for (final node in snap.nodes)
        {
          'role': node.role,
          if ((node.name ?? '').isNotEmpty) 'name': node.name,
          if ((node.value ?? '').isNotEmpty) 'value': node.value,
        },
    ];
    return File('${directory.path}/ax_$label.json')
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(nodes),
      );
  }
}

String _js(String value) =>
    "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";
