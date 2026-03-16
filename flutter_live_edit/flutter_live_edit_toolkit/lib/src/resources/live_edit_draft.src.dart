import 'package:flutter/foundation.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import 'live_edit_draft.src.data.dart';

/// Holds draft state per session+domain: draftChanges, meaningfulNodeIds.
final class LiveEditDraftResource extends ValueNotifier<LiveEditDraftState> {
  LiveEditDraftResource([super.initialValue = const {}]);
}
