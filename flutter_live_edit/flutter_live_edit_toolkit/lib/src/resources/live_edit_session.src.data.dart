import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

/// Immutable data for [LiveEditSessionResource].
final class LiveEditSessionResourceData {
  const LiveEditSessionResourceData({
    this.activeSessionId,
    this.overlayVisible = false,
    this.targetDomain = LiveEditTargetDomain.appScene,
    this.sessionIds = const <String>[],
  });

  final String? activeSessionId;
  final bool overlayVisible;
  final LiveEditTargetDomain targetDomain;
  final List<String> sessionIds;

  static const LiveEditSessionResourceData initial =
      LiveEditSessionResourceData();

  LiveEditSessionResourceData copyWith({
    final Object? activeSessionId = _unset,
    final bool? overlayVisible,
    final LiveEditTargetDomain? targetDomain,
    final List<String>? sessionIds,
  }) =>
      LiveEditSessionResourceData(
        activeSessionId: identical(activeSessionId, _unset)
            ? this.activeSessionId
            : activeSessionId as String?,
        overlayVisible: overlayVisible ?? this.overlayVisible,
        targetDomain: targetDomain ?? this.targetDomain,
        sessionIds: sessionIds ?? this.sessionIds,
      );
}

const Object _unset = Object();
