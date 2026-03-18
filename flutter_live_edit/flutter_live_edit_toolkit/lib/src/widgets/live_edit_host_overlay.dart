part of '../live_edit_host.dart';

class _EditorPanelSurface extends StatelessWidget {
  const _EditorPanelSurface({
    required this.context,
    required this.controller,
    this.railPanelViewModel,
    this.panelCallbacks,
    this.bubbleCallbacks,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final PanelViewModel? railPanelViewModel;
  final PanelCallbacks? panelCallbacks;
  final BubbleCallbacks? bubbleCallbacks;

  @override
  Widget build(final BuildContext buildContext) {
    final railVm =
        railPanelViewModel ??
        buildPanelViewModel(
          context,
          controller,
          MediaQuery.sizeOf(buildContext),
          buildToolingThemeData(),
        );
    final panelCb = panelCallbacks ?? ToolLayerPanelCallbacks(context: context);
    final bubbleCb =
        bubbleCallbacks ??
        ToolLayerBubbleCallbacks(context: context, controller: controller);
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: KeyedSubtree(
            key: LiveEditOverlayThemeModel.instance.keyFor(
              selectPanelExpanded(context)
                  ? kLiveEditPanelExpandedSurfaceId
                  : kLiveEditPanelRailSurfaceId,
            ),
            child: PanelSurface(
              viewModel: railVm,
              callbacks: panelCb,
              bubbleCallbacks: bubbleCb,
              expandedChild: _PropertyPanel(
                key: const ValueKey<String>('expanded_panel'),
                context: context,
                controller: controller,
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: PanelDragHandle(
            onPanUpdate: (final details) =>
                DragPanelCommand(delta: details.delta).execute(context),
          ),
        ),
        Positioned(
          right: 6,
          bottom: 6,
          child: PanelResizeHandle(
            onPanUpdate: (final details) => ResizePanelCommand(
              width: selectPanelWidth(context) + details.delta.dx,
              height: selectPanelHeight(context) + details.delta.dy,
            ).execute(context),
          ),
        ),
      ],
    );
  }
}

class _LauncherChip extends StatelessWidget {
  const _LauncherChip({required this.context, required this.controller});

  final LiveEditContext context;
  final LiveEditController controller;

  @override
  Widget build(final BuildContext buildContext) {
    final overlayVisible = selectOverlayVisible(context);
    return Material(
      color: Colors.transparent,
      child: Semantics(
        identifier: 'live_edit_launcher_chip',
        child: ActionChip(
          label: Text(overlayVisible ? 'Live Edit: ON' : 'Live Edit'),
          avatar: Icon(
            overlayVisible ? Icons.tune : Icons.tune_outlined,
            size: 18,
          ),
          onPressed: () {
            SetOverlayEnabledCommand(enabled: !overlayVisible).execute(context);
          },
        ),
      ),
    );
  }
}

class _SelectionBubble extends StatelessWidget {
  const _SelectionBubble({
    required this.context,
    required this.controller,
    required this.viewportSize,
    this.bubbleSummary,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final Size viewportSize;
  final LiveEditBubbleSummary? bubbleSummary;

  List<LiveEditSelectionCandidate> get _visibleCandidates {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    return controller
        .selectionCandidatesForDomain(
          targetDomain: presentationDomain,
          sessionId: sessionId,
        )
        .take(3)
        .toList(growable: false);
  }

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final overlayTheme = LiveEditOverlayThemeModel.instance;
    final summary = bubbleSummary;
    final LiveEditSelection? selection;
    final LiveEditBounds? bounds;
    final LiveEditBubbleStatus status;
    final Offset placement;
    final bool isActive;
    final Key bubbleKey;
    final pv = context.panelViewResource.value;
    final bubbleWidth = pv.bubbleWidth;
    if (summary != null) {
      final record = selectBubbleRecord(context, summary.bubbleId);
      selection = record?.primarySelection;
      final boundsOrFallback = summary.bounds ?? selection?.bounds;
      bounds =
          boundsOrFallback ??
          const LiveEditBounds(
            left: 100,
            top: 100,
            right: 400,
            bottom: 340,
            width: 300,
            height: 240,
          );
      status = selectBubbleStatusForBubble(context, summary.bubbleId);
      placement = clampBubblePlacement(
        placement:
            autoBubblePlacement(
              bounds: bounds,
              viewport: viewportSize,
              bubbleWidth: overlayTheme.selectionBubbleWidth(
                aiMode: selectEditMode(context) == LiveEditEditMode.ai,
              ),
              bubbleHeight: overlayTheme.selectionBubbleHeight(
                aiMode: selectEditMode(context) == LiveEditEditMode.ai,
              ),
            ) +
            selectBubbleDragOffset(context, summary.bubbleId),
        viewport: viewportSize,
        bubbleWidth: overlayTheme.selectionBubbleWidth(
          aiMode: selectEditMode(context) == LiveEditEditMode.ai,
        ),
        bubbleHeight: overlayTheme.selectionBubbleHeight(
          aiMode: selectEditMode(context) == LiveEditEditMode.ai,
        ),
      );
      isActive = summary.active;
      bubbleKey = isActive
          ? overlayTheme.keyFor(
              selectEditMode(context) == LiveEditEditMode.ai
                  ? kLiveEditAiBubbleSurfaceId
                  : kLiveEditSelectionBubbleSurfaceId,
            )
          : ValueKey<String>('bubble_${summary.bubbleId}');
    } else {
      selection = selectSelectionForDomain(
        context,
        controller,
        domain: presentationDomain,
        sessionId: sessionId,
      );
      bounds = selection?.bounds;
      if (selection == null || bounds == null) {
        return const SizedBox.shrink();
      }
      status = selectBubbleStatusForBubble(
        context,
        selectActiveBubbleId(
          context,
          controller,
          presentationDomain: presentationDomain,
          sessionId: sessionId,
        ),
      );
      placement = clampBubblePlacement(
        placement:
            autoBubblePlacement(
              bounds: bounds,
              viewport: viewportSize,
              bubbleWidth: overlayTheme.selectionBubbleWidth(
                aiMode: selectEditMode(context) == LiveEditEditMode.ai,
              ),
              bubbleHeight: overlayTheme.selectionBubbleHeight(
                aiMode: selectEditMode(context) == LiveEditEditMode.ai,
              ),
            ) +
            selectBubbleDragOffset(
              context,
              selectActiveBubbleId(
                context,
                controller,
                presentationDomain: presentationDomain,
                sessionId: sessionId,
              ),
            ),
        viewport: viewportSize,
        bubbleWidth: overlayTheme.selectionBubbleWidth(
          aiMode: selectEditMode(context) == LiveEditEditMode.ai,
        ),
        bubbleHeight: overlayTheme.selectionBubbleHeight(
          aiMode: selectEditMode(context) == LiveEditEditMode.ai,
        ),
      );
      isActive = true;
      bubbleKey = overlayTheme.keyFor(
        selectEditMode(context) == LiveEditEditMode.ai
            ? kLiveEditAiBubbleSurfaceId
            : kLiveEditSelectionBubbleSurfaceId,
      );
    }

    final aiMode = selectEditMode(context) == LiveEditEditMode.ai;
    final surfaceId = aiMode
        ? kLiveEditAiBubbleSurfaceId
        : kLiveEditSelectionBubbleSurfaceId;
    final surfaceTheme = overlayTheme.styleFor(surfaceId);
    final bubbleWidthVal = overlayTheme.selectionBubbleWidth(aiMode: aiMode);
    final bubbleHeightVal = overlayTheme.selectionBubbleHeight(aiMode: aiMode);
    final autoPlacement = autoBubblePlacement(
      bounds: bounds,
      viewport: viewportSize,
      bubbleWidth: bubbleWidthVal,
      bubbleHeight: bubbleHeightVal,
    );

    return Positioned(
      left: placement.dx,
      top: placement.dy,
      width: bubbleWidth,
      child: KeyedSubtree(
        key: bubbleKey,
        child: Semantics(
          identifier: isActive
              ? (aiMode ? 'live_edit_ai_bubble' : 'live_edit_selection_bubble')
              : (aiMode
                    ? 'live_edit_ai_bubble_${summary?.bubbleId ?? 'other'}'
                    : 'live_edit_selection_bubble_${summary?.bubbleId ?? 'other'}'),
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(surfaceTheme.cornerRadius),
            color: surfaceTheme.backgroundColor,
            child: Container(
              height: bubbleHeightVal,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(surfaceTheme.cornerRadius),
                border: Border.all(color: surfaceTheme.borderColor),
              ),
              child: Stack(
                children: <Widget>[
                  Padding(
                    padding: surfaceTheme.padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (surfaceTheme.showDragHandle)
                          BubbleDragHandle(
                            alignment: autoPlacement.dx > bounds.left
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            onPanUpdate: (final details) {
                              if (summary != null) {
                                DragBubbleForCommand(
                                  bubbleId: summary.bubbleId,
                                  delta: details.delta,
                                ).execute(context);
                              } else {
                                DragBubbleCommand(
                                  delta: details.delta,
                                ).execute(context);
                              }
                            },
                            semanticsId: isActive
                                ? 'live_edit_bubble_drag_handle'
                                : 'live_edit_bubble_drag_handle_${summary?.bubbleId ?? 'other'}',
                          ),
                        if (status == LiveEditBubbleStatus.applied)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: const Text(
                              'Last apply succeeded. Review the updated node or discard the session draft state.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    isActive &&
                                            selectHasMarqueePreview(
                                              context,
                                              controller,
                                              presentationDomain:
                                                  presentationDomain,
                                              sessionId: sessionId,
                                            )
                                        ? 'Selecting ${selectMarqueePreviewSelections(context, controller, presentationDomain: presentationDomain, sessionId: sessionId).length}'
                                        : isActive
                                        ? (selectCurrentActivity(
                                                context,
                                                controller,
                                                presentationDomain:
                                                    presentationDomain,
                                                sessionId: sessionId,
                                              )?.label ??
                                              _bubbleStatusLabel(status))
                                        : _bubbleStatusLabel(status),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isActive &&
                                            selectHasMultiSelection(
                                              context,
                                              controller,
                                              presentationDomain:
                                                  presentationDomain,
                                              sessionId: sessionId,
                                            )
                                        ? '${selectMultiSelectionForDomain(context, controller, domain: presentationDomain, sessionId: sessionId).length} widgets • shared'
                                        : isActive &&
                                              selectHasMarqueePreview(
                                                context,
                                                controller,
                                                presentationDomain:
                                                    presentationDomain,
                                                sessionId: sessionId,
                                              )
                                        ? 'Drag selection preview • ${selectMarqueePreviewSelections(context, controller, presentationDomain: presentationDomain, sessionId: sessionId).length} hits'
                                        : '${selection?.widgetType ?? summary?.label ?? '?'} • node',
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (selectDebugModeEnabled(context) &&
                                      selection != null &&
                                      _hasText(
                                        _sourceLocationLabel(
                                          selection.source,
                                          compact: true,
                                        ),
                                      ))
                                    Text(
                                      _sourceLocationLabel(
                                        selection.source,
                                        compact: true,
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (selectDebugModeEnabled(context) &&
                                      selection != null &&
                                      !_hasText(
                                        _sourceLocationLabel(
                                          selection.source,
                                          compact: true,
                                        ),
                                      ))
                                    const Text(
                                      'No concrete source context',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Semantics(
                              identifier: 'live_edit_select_parent_button',
                              button: true,
                              child: IconButton(
                                onPressed:
                                    isActive && _visibleCandidates.length > 1
                                    ? () => SelectParentCandidateCommand(
                                        controller: controller,
                                      ).execute(context)
                                    : null,
                                icon: const Icon(
                                  Icons.vertical_align_top,
                                  size: 18,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Sticky deeper pick',
                              onPressed: () => SetDeeperPickCommand(
                                enabled: !selectDeeperPickEnabled(context),
                              ).execute(context),
                              icon: Icon(
                                selectDeeperPickEnabled(context)
                                    ? Icons.layers
                                    : Icons.layers_outlined,
                                size: 18,
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  isActive && _visibleCandidates.length > 1
                                  ? () => SelectChildCandidateCommand(
                                      controller: controller,
                                    ).execute(context)
                                  : null,
                              icon: const Icon(
                                Icons.vertical_align_bottom,
                                size: 18,
                              ),
                            ),
                            Semantics(
                              identifier: isActive
                                  ? 'live_edit_bubble_hide_button'
                                  : 'live_edit_bubble_hide_button_${summary?.bubbleId ?? 'other'}',
                              button: true,
                              child: IconButton(
                                tooltip: 'Hide bubble',
                                onPressed: summary != null
                                    ? () => HideBubbleCommand(
                                        bubbleId: summary.bubbleId,
                                      ).execute(context)
                                    : () => HideBubbleCommand(
                                        bubbleId: selectActiveBubbleId(
                                          context,
                                          controller,
                                          presentationDomain:
                                              presentationDomain,
                                          sessionId: sessionId,
                                        ),
                                      ).execute(context),
                                icon: const Icon(Icons.visibility_off_outlined),
                              ),
                            ),
                          ],
                        ),
                        if (isActive) ...[
                          SizedBox(height: surfaceTheme.gap),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: <Widget>[
                                for (final candidate
                                    in _visibleCandidates.indexed) ...<Widget>[
                                  Semantics(
                                    identifier:
                                        'live_edit_candidate_chip_${candidate.$1}',
                                    child: ChoiceChip(
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      label: Text(
                                        _candidateLabel(candidate.$1),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      selected: candidate.$2.active,
                                      onSelected: (_) {
                                        final activeIdx = _visibleCandidates
                                            .indexWhere((final c) => c.active);
                                        if (activeIdx < 0) return;
                                        final len = _visibleCandidates.length;
                                        final delta =
                                            (candidate.$1 - activeIdx + len) %
                                            len;
                                        if (delta == 0) return;
                                        CycleSelectionCandidateCommand(
                                          controller: controller,
                                          delta: delta,
                                        ).execute(context);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (controller
                                        .selectionCandidatesForDomain(
                                          targetDomain: presentationDomain,
                                          sessionId: sessionId,
                                        )
                                        .length >
                                    _visibleCandidates.length)
                                  Chip(
                                    label: Text(
                                      '+${controller.selectionCandidatesForDomain(targetDomain: presentationDomain, sessionId: sessionId).length - _visibleCandidates.length}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: surfaceTheme.gap),
                        ],
                        Expanded(
                          child: switch (status) {
                            LiveEditBubbleStatus.waiting => _WaitingBubbleBody(
                              context: context,
                              controller: controller,
                              bubbleId: !isActive && summary != null
                                  ? summary.bubbleId
                                  : null,
                            ),
                            LiveEditBubbleStatus.failed => _WaitingBubbleBody(
                              context: context,
                              controller: controller,
                              bubbleId: !isActive && summary != null
                                  ? summary.bubbleId
                                  : null,
                            ),
                            LiveEditBubbleStatus.applied => _AppliedBubbleBody(
                              context: context,
                              controller: controller,
                              bubbleId: !isActive && summary != null
                                  ? summary.bubbleId
                                  : null,
                            ),
                            _
                                when selectEditMode(context) ==
                                    LiveEditEditMode.ai =>
                              _AiBubbleBody(
                                context: context,
                                controller: controller,
                                bubbleId: !isActive && summary != null
                                    ? summary.bubbleId
                                    : null,
                                autofocus: isActive,
                              ),
                            _ => _SelectionBubbleBody(
                              context: context,
                              controller: controller,
                              bubbleId: !isActive && summary != null
                                  ? summary.bubbleId
                                  : null,
                            ),
                          },
                        ),
                      ],
                    ),
                  ),
                  if (surfaceTheme.showResizeHandle)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: BubbleResizeHandle(
                        onPanUpdate: (final details) {
                          ResizeBubbleCommand(
                            width: bubbleWidthVal + details.delta.dx,
                            height: bubbleHeightVal + details.delta.dy,
                          ).execute(context);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _candidateLabel(final int index) => switch (index) {
    0 => 'Selected',
    1 => 'Parent',
    2 => 'Child',
    _ => 'Alt ${index + 1}',
  };
}

