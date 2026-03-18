import 'package:flutter/foundation.dart';

import 'live_edit_draft.src.data.dart';

/// Holds draft state per session+domain: draftChanges, meaningfulNodeIds.
final class LiveEditDraftResource extends ValueNotifier<LiveEditDraftState> {
  LiveEditDraftResource([super.initialValue = const {}]);
}
