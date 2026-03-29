// ignore_for_file: invalid_use_of_protected_member, unused_element

part of '../live_edit_session_service.dart';

final class _ElementHit {
  const _ElementHit({
    required this.element,
    required this.renderObject,
    required this.ancestry,
    required this.depth,
    this.parentElement,
    this.edgeHit = false,
  });

  final Element element;
  final RenderObject renderObject;
  final List<Map<String, Object?>> ancestry;
  final int depth;
  final Element? parentElement;
  final bool edgeHit;
}

enum _SelectionSetOrigin {
  unknown,
  hitTest,
  marquee,
  candidate,
  hydrate,
  surface,
}

enum _SelectionFocusKind {
  single,
  multi,
}

final class _SelectionSetState {
  const _SelectionSetState({
    required this.primaryKey,
    required this.memberKeys,
    required this.origin,
    required this.focusKind,
  });

  const _SelectionSetState.empty()
      : primaryKey = null,
        memberKeys = const <String>[],
        origin = _SelectionSetOrigin.unknown,
        focusKind = _SelectionFocusKind.single;

  final String? primaryKey;
  final List<String> memberKeys;
  final _SelectionSetOrigin origin;
  final _SelectionFocusKind focusKind;

  bool get isEmpty => memberKeys.isEmpty;

  bool get isSingle => memberKeys.length == 1;

  bool contains(final String selectionKey) => memberKeys.contains(selectionKey);

  _SelectionSetState normalized({
    final String? primaryKey,
    final _SelectionSetOrigin? origin,
    final _SelectionFocusKind? focusKind,
  }) {
    final keys = _canonicalSelectionKeys(memberKeys);
    final resolvedPrimary = _hasText(primaryKey) && keys.contains(primaryKey)
        ? primaryKey!.trim()
        : (keys.isEmpty ? null : keys.first);
    return _SelectionSetState(
      primaryKey: resolvedPrimary,
      memberKeys: keys,
      origin: origin ?? this.origin,
      focusKind: focusKind ?? this.focusKind,
    );
  }
}

final class _LiveEditSessionState {
  _LiveEditSessionState({required this.sessionId, required this.objectGroup});

  final String sessionId;
  final String objectGroup;
  LiveEditTargetDomain targetDomain = LiveEditTargetDomain.appScene;
  bool overlayEnabled = false;
  final _LiveEditLayerState appLayer = _LiveEditLayerState();
  final _LiveEditLayerState toolLayer = _LiveEditLayerState();
  final Map<Element, String> fallbackSelectionKeys = <Element, String>{};
  int fallbackSelectionKeyCounter = 0;
  DateTime lastTouchedAt = DateTime.now().toUtc();

  _LiveEditLayerState layerFor(final LiveEditTargetDomain domain) =>
      switch (domain) {
        LiveEditTargetDomain.appScene => appLayer,
        LiveEditTargetDomain.toolScene => toolLayer,
      };

  _LiveEditLayerState get currentLayer => layerFor(targetDomain);

  Element? get selectedElement => currentLayer.selectedElement;
  set selectedElement(final Element? value) =>
      currentLayer.selectedElement = value;

  LiveEditSelection? get selection => currentLayer.selection;
  set selection(final LiveEditSelection? value) =>
      currentLayer.selection = value;

  LiveEditSelection? get hoverSelection => currentLayer.hoverSelection;
  set hoverSelection(final LiveEditSelection? value) =>
      currentLayer.hoverSelection = value;

  ui.Offset? get hoverPoint => currentLayer.hoverPoint;
  set hoverPoint(final ui.Offset? value) => currentLayer.hoverPoint = value;

  Element? get hoverRootElement => currentLayer.hoverRootElement;
  set hoverRootElement(final Element? value) =>
      currentLayer.hoverRootElement = value;

  int? get hoverViewId => currentLayer.hoverViewId;
  set hoverViewId(final int? value) => currentLayer.hoverViewId = value;

  List<Map<String, Object?>> get ancestry => currentLayer.ancestry;
  set ancestry(final List<Map<String, Object?>> value) =>
      currentLayer.ancestry = value;

  List<_ElementHit> get selectionHitCandidates =>
      currentLayer.selectionHitCandidates;
  set selectionHitCandidates(final List<_ElementHit> value) =>
      currentLayer.selectionHitCandidates = value;

  List<_ElementHit> get hoverHitCandidates => currentLayer.hoverHitCandidates;
  set hoverHitCandidates(final List<_ElementHit> value) =>
      currentLayer.hoverHitCandidates = value;

  List<LiveEditSelectionCandidate> get selectionCandidates =>
      currentLayer.selectionCandidates;
  set selectionCandidates(final List<LiveEditSelectionCandidate> value) =>
      currentLayer.selectionCandidates = value;

  int get hoverPreviewIndex => currentLayer.hoverPreviewIndex;
  set hoverPreviewIndex(final int value) =>
      currentLayer.hoverPreviewIndex = value;

  ui.Offset? get marqueeStart => currentLayer.marqueeStart;
  set marqueeStart(final ui.Offset? value) => currentLayer.marqueeStart = value;

  Rect? get marqueeRect => currentLayer.marqueeRect;
  set marqueeRect(final Rect? value) => currentLayer.marqueeRect = value;

  List<_ElementHit> get marqueeHits => currentLayer.marqueeHits;
  set marqueeHits(final List<_ElementHit> value) =>
      currentLayer.marqueeHits = value;

  List<LiveEditSelection> get marqueeSelections =>
      currentLayer.marqueeSelections;
  set marqueeSelections(final List<LiveEditSelection> value) =>
      currentLayer.marqueeSelections = value;

  List<LiveEditSelection> get multiSelections => currentLayer.multiSelections;
  set multiSelections(final List<LiveEditSelection> value) =>
      currentLayer.multiSelections = value;

  _SelectionSetState get selectionSet => currentLayer.selectionSet;
  set selectionSet(final _SelectionSetState value) =>
      currentLayer.selectionSet = value;

  _SelectionSetState get marqueeSelectionSet => currentLayer.marqueeSelectionSet;
  set marqueeSelectionSet(final _SelectionSetState value) =>
      currentLayer.marqueeSelectionSet = value;

  Map<Element, _MarqueeCandidateCacheEntry> get marqueeCache =>
      currentLayer.marqueeCache;

  Map<String, Object?> get originalExactValues =>
      currentLayer.originalExactValues;

  Set<String> get meaningfulNodeIds => currentLayer.meaningfulNodeIds;

  Map<String, _TrackedSelectionTarget> get trackedSelections =>
      currentLayer.trackedSelections;
}

final class _LiveEditLayerState {
  Element? selectedElement;
  LiveEditSelection? selection;
  LiveEditSelection? hoverSelection;
  ui.Offset? hoverPoint;
  Element? hoverRootElement;
  int? hoverViewId;
  List<Map<String, Object?>> ancestry = const <Map<String, Object?>>[];
  List<_ElementHit> selectionHitCandidates = const <_ElementHit>[];
  List<_ElementHit> hoverHitCandidates = const <_ElementHit>[];
  List<LiveEditSelectionCandidate> selectionCandidates =
      const <LiveEditSelectionCandidate>[];
  int hoverPreviewIndex = 0;
  ui.Offset? marqueeStart;
  Rect? marqueeRect;
  List<_ElementHit> marqueeHits = const <_ElementHit>[];
  List<LiveEditSelection> marqueeSelections = const <LiveEditSelection>[];
  List<LiveEditSelection> multiSelections = const <LiveEditSelection>[];
  _SelectionSetState selectionSet = const _SelectionSetState.empty();
  _SelectionSetState marqueeSelectionSet = const _SelectionSetState.empty();
  final Map<Element, _MarqueeCandidateCacheEntry> marqueeCache =
      <Element, _MarqueeCandidateCacheEntry>{};
  final Map<String, Object?> originalExactValues = <String, Object?>{};
  final Set<String> meaningfulNodeIds = <String>{};
  final Map<String, _TrackedSelectionTarget> trackedSelections =
      <String, _TrackedSelectionTarget>{};
}

final class _TrackedSelectionTarget {
  const _TrackedSelectionTarget({
    required this.element,
    required this.ancestry,
    required this.selection,
  });

  final Element element;
  final List<Map<String, Object?>> ancestry;
  final LiveEditSelection selection;
}
