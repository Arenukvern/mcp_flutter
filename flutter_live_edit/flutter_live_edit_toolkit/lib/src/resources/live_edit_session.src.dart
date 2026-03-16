import 'package:flutter/foundation.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import 'live_edit_session.src.data.dart';

/// Holds session UI state: activeSessionId, overlayVisible, targetDomain.
final class LiveEditSessionResource extends ValueNotifier<LiveEditSessionResourceData> {
  LiveEditSessionResource([
    super.initialValue = LiveEditSessionResourceData.initial,
  ]);
}
