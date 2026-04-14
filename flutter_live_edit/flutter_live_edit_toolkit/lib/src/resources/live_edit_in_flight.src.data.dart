import '../models/models.dart';

/// Immutable snapshot of in-flight bubble runs, keyed by bubble id.
///
/// The orchestrator mutates this resource via
/// `RegisterInFlightBubbleCommand` / `CompleteInFlightBubbleCommand` /
/// `UnregisterInFlightBubbleCommand`; UI observers (panel chips) read it via
/// selectors.
final class LiveEditInFlightResourceData {
  const LiveEditInFlightResourceData({
    this.recordsByBubbleId = const <String, LiveEditInFlightRecord>{},
  });

  final Map<String, LiveEditInFlightRecord> recordsByBubbleId;

  static const LiveEditInFlightResourceData initial =
      LiveEditInFlightResourceData();

  LiveEditInFlightResourceData copyWith({
    final Map<String, LiveEditInFlightRecord>? recordsByBubbleId,
  }) => LiveEditInFlightResourceData(
    recordsByBubbleId: recordsByBubbleId ?? this.recordsByBubbleId,
  );
}
