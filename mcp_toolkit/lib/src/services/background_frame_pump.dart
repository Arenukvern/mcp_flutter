import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Manually drives the frame pipeline when the engine delivers no vsync — a
/// backgrounded/occluded desktop window suspends frames, so dispatched
/// actions would otherwise never reach build/layout/paint/semantics and every
/// snapshot or screenshot would show the pre-action screen.
///
/// Two frames are pumped: the first starts any just-triggered time-based
/// animations, the second — far in the future — completes them. A microtask
/// yield between [SchedulerBinding.handleBeginFrame] and
/// [SchedulerBinding.handleDrawFrame] preserves the engine's mid-frame
/// microtask phase, so futures completed by transient callbacks run before
/// paint. Raw timestamps come from the wall clock, which is monotonic across
/// calls and far above the engine's frame clock; [SchedulerBinding.resetEpoch]
/// afterwards keeps the adjusted timeline continuous, so vsync frames resume
/// without a time jump when the window becomes visible again.
Future<void> pumpFramesIfSuspended() async {
  // Web tabs throttle rAF instead of reporting a hidden lifecycle; driving
  // the pipeline manually there is untested — keep this desktop/mobile only.
  if (kIsWeb) return;
  final binding = WidgetsBinding.instance;
  if (binding.framesEnabled) return;
  if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) return;
  // A microtask yield (not an event-loop timer: zero-duration timers
  // deadlock under the FakeAsync test zone) flushes mid-frame microtasks.
  Future<void> yieldMicrotasks() => Future<void>.microtask(() {});
  var raw = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
  binding.handleBeginFrame(raw);
  await yieldMicrotasks();
  binding.handleDrawFrame();
  raw += const Duration(minutes: 10);
  await yieldMicrotasks();
  binding.handleBeginFrame(raw);
  await yieldMicrotasks();
  binding
    ..handleDrawFrame()
    ..resetEpoch();
}
