import 'package:flutter/foundation.dart';

import 'live_edit_selection.src.data.dart';

/// Holds selection state per session+domain: selection, hover, marquee, multi, candidates.
final class LiveEditSelectionResource
    extends ValueNotifier<LiveEditSelectionState> {
  LiveEditSelectionResource([super.initialValue = const {}]);
}
