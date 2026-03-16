import 'package:flutter/foundation.dart';

import 'live_edit_bubble.src.data.dart';

/// Holds bubble records, apply phase, and layer view state.
final class LiveEditBubbleResource
    extends ValueNotifier<LiveEditBubbleResourceData> {
  LiveEditBubbleResource([final LiveEditBubbleResourceData? initialValue])
    : super(initialValue ?? LiveEditBubbleResourceData.initial);
}
