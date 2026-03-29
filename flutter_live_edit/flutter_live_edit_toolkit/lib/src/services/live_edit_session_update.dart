import '../models/models.dart';
import '../resources/live_edit_draft.src.data.dart';
import '../resources/live_edit_selection.src.data.dart';
import '../resources/live_edit_session.src.data.dart';

/// Result of a session service call; Commands apply these to Resources.
final class LiveEditSessionUpdate {
  const LiveEditSessionUpdate({
    this.sessionData,
    this.selectionStore,
    this.draftStore,
    this.flowGraph = FlowGraphSnapshot.empty,
    this.rawResult,
  });

  final LiveEditSessionResourceData? sessionData;
  final LiveEditSelectionStore? selectionStore;
  final LiveEditDraftStore? draftStore;
  final FlowGraphSnapshot? flowGraph;
  final Map<String, Object?>? rawResult;
}
