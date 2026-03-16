import 'package:flutter/foundation.dart';

import 'live_edit_panel_view.src.data.dart';

/// Holds panel dimensions, edit mode, and debug flags.
final class LiveEditPanelViewResource
    extends ValueNotifier<LiveEditPanelViewResourceData> {
  LiveEditPanelViewResource([
    super.initialValue = LiveEditPanelViewResourceData.initial,
  ]);
}
