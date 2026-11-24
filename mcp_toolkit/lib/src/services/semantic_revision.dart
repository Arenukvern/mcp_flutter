import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Cheap semantics revision counter (ADR 0023 spike).
///
/// Flutter does not expose a public semantics-owner revision, so this bumps on
/// every scheduled frame while semantics is enabled. It is **not** wired into
/// production snapshot elision — `stable`/`changed` still walk each sample —
/// because frame scheduling alone does not prove the semantics tree mutated.
mixin SemanticRevisionProbe {
  static int _revision = 0;
  static int get revision => _revision;

  static bool _hooked = false;

  /// Call once during binding setup or first snapshot (idempotent).
  static void ensureHooked() {
    if (_hooked) return;
    _hooked = true;
    final binding = WidgetsBinding.instance;
    binding.addPersistentFrameCallback((_) {
      _revision++;
    });
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _revision++;
    });
  }
}