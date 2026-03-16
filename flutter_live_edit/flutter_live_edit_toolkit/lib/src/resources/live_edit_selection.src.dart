import 'package:flutter/foundation.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import 'live_edit_selection.src.data.dart';

/// Holds selection state per session+domain: selection, hover, marquee, multi, candidates.
final class LiveEditSelectionResource
    extends ValueNotifier<LiveEditSelectionState> {
  LiveEditSelectionResource([super.initialValue = const {}]);
}
