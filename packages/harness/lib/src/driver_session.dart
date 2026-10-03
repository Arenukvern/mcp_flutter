import 'dart:async';

import 'package:universal_automation_interface/universal_automation_interface.dart';

import 'flutter_app.dart';
import 'toolkit_driver.dart';

/// Attaches a [ToolkitDriver] to a launched app — the launch/attach/drive
/// glue every consumer used to re-derive from `LaunchedApp.vm()`.
///
/// ```dart
/// final app = await FlutterRunTarget(projectDir: 'my_app').launch();
/// final driver = await attachDriver(app);
/// ```
///
/// Connection ownership stays with [LaunchedApp]: [ToolkitDriver.close]
/// releases the driver, not the process or its VM service (the target
/// that launched the app keeps owning those).
Future<ToolkitDriver> attachDriver(final LaunchedApp app) async =>
    ToolkitDriver(await app.vm());

/// Observe-until helpers over the driver's semantic snapshot — the
/// retry-until-rendered loop every drive program needs (a tap lands
/// before the next frame paints; verifying immediately reads the old
/// tree).
extension ToolkitDriverObserve on ToolkitDriver {
  /// Polls [snapshot] until some node label contains [needle]
  /// (case-sensitive substring, snapshot order).
  ///
  /// Returns the matched label, or `null` after [attempts] misses —
  /// use [expectLabel] when a miss should fail loudly.
  Future<String?> labelContaining(
    final String needle, {
    final int attempts = 10,
    final Duration delay = const Duration(milliseconds: 500),
    final void Function(String surface)? onMiss,
  }) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      final nodes = (await snapshot()).nodes.toList();
      for (final node in nodes) {
        final label = node.name;
        if (label != null && label.contains(needle)) return label;
      }
      if (attempt == attempts - 1) {
        onMiss?.call(_surfaceDump(nodes));
      }
      await Future<void>.delayed(delay);
    }
    return null;
  }

  /// [labelContaining] that fails loudly: throws [StateError] carrying
  /// the needle and a dump of the surface the driver actually saw, so a
  /// failed verify reports what was on screen instead of a bare timeout.
  Future<String> expectLabel(
    final String needle, {
    final int attempts = 10,
    final Duration delay = const Duration(milliseconds: 500),
  }) async {
    String surface = '';
    final label = await labelContaining(
      needle,
      attempts: attempts,
      delay: delay,
      onMiss: (final dump) => surface = dump,
    );
    if (label == null) {
      throw StateError(
        'label "$needle" not on screen after $attempts attempts; '
        'surface: $surface',
      );
    }
    return label;
  }
}

String _surfaceDump(final List<AxNode> nodes) => nodes
    .map((node) => node.name ?? node.role)
    .where((label) => label.isNotEmpty)
    .join(' | ');
