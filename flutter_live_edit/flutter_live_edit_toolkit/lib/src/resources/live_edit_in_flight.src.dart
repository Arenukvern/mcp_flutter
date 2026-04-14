import 'package:flutter/foundation.dart';

import 'live_edit_in_flight.src.data.dart';

/// Tracks in-flight AI bubble runs so the orchestrator can coordinate
/// overlapping widget-subtree edits across parallel bubbles.
final class LiveEditInFlightResource
    extends ValueNotifier<LiveEditInFlightResourceData> {
  LiveEditInFlightResource([
    final LiveEditInFlightResourceData? initialValue,
  ]) : super(initialValue ?? LiveEditInFlightResourceData.initial);
}
