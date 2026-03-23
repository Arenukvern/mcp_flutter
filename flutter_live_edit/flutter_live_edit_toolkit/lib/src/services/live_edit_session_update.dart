import '../models/models.dart';
import '../resources/live_edit_draft.src.data.dart';
import '../resources/live_edit_selection.src.data.dart';
import '../resources/live_edit_session.src.data.dart';

/// Result of a session service call; Commands apply these to Resources.
final class LiveEditSessionUpdate {
  const LiveEditSessionUpdate({
    this.sessionData,
    this.selectionLayer,
    this.draftLayer,
    this.rawResult,
  });

  final LiveEditSessionResourceData? sessionData;
  final (
    String sessionId,
    LiveEditTargetDomain domain,
    LiveEditSelectionLayerData data,
  )?
  selectionLayer;
  final (
    String sessionId,
    LiveEditTargetDomain domain,
    LiveEditDraftLayerData data,
  )?
  draftLayer;
  final Map<String, Object?>? rawResult;
}
