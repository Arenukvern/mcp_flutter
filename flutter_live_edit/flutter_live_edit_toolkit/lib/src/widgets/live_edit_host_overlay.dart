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

    final chatVm = buildChatBubbleViewModel(
      context,
      controller,
      bubbleId: summary?.bubbleId,
    );
    final chatCb = ToolLayerChatBubbleCallbacks(
      context: context,
      controller: controller,
      bubbleId: summary?.bubbleId,
    );
    final useChatBody =
        status != LiveEditBubbleStatus.waiting &&
        status != LiveEditBubbleStatus.failed;
    final effectiveHeight = useChatBody
        ? ((!chatVm.showThinking || chatVm.messages.isEmpty)
              ? 220.0
              : overlayTheme.selectionBubbleHeight(aiMode: true))
        : bubbleHeightVal;
    final radius = BorderRadius.circular(surfaceTheme.cornerRadius);
    final bubbleBody = useChatBody
        ? ChatBubbleSurface(
            viewModel: chatVm,
            callbacks: chatCb,
            autofocus: true,
          )
        : _WaitingBubbleBody(
            context: context,
            controller: controller,
            bubbleId: !isActive && summary != null ? summary.bubbleId : null,
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
          child: Container(
            height: effectiveHeight,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 32,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surfaceTheme.backgroundColor,
                    borderRadius: radius,
                    border: Border.all(
                      color: surfaceTheme.borderColor,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      _AiBubbleDragBar(
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
                      ),
                      if (!aiMode && isActive) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      selectHasMarqueePreview(
                                            context,
                                            controller,
                                            presentationDomain:
                                                presentationDomain,
                                            sessionId: sessionId,
                                          )
                                          ? 'Selecting ${selectMarqueePreviewSelections(context, controller, presentationDomain: presentationDomain, sessionId: sessionId).length}'
                                          : (selectCurrentActivity(
                                                  context,
                                                  controller,
                                                  presentationDomain:
                                                      presentationDomain,
                                                  sessionId: sessionId,
                                                )?.label ??
                                                _bubbleStatusLabel(status)),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${selection?.widgetType ?? summary?.label ?? '?'} • node',
                                      style: const TextStyle(
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
                                  onPressed: _visibleCandidates.length > 1
                                      ? () => SelectParentCandidateCommand(
                                          controller: controller,
                                        ).execute(context)
                                      : null,
                                  icon: const Icon(
                                    Icons.vertical_align_top,
                                    size: 16,
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
                                  size: 16,
                                ),
                              ),
                              IconButton(
                                onPressed: _visibleCandidates.length > 1
                                    ? () => SelectChildCandidateCommand(
                                        controller: controller,
                                      ).execute(context)
                                    : null,
                                icon: const Icon(
                                  Icons.vertical_align_bottom,
                                  size: 16,
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
                                  icon: const Icon(
                                    Icons.visibility_off_outlined,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                        const SizedBox(height: 4),
                      ],
                      Expanded(child: bubbleBody),
                      if (surfaceTheme.showResizeHandle)
                        _AiBubbleResizeBar(
                          onPanUpdate: (final details) {
                            ResizeBubbleCommand(
                              width: bubbleWidthVal + details.delta.dx,
                              height: effectiveHeight + details.delta.dy,
                            ).execute(context);
                          },
                        ),
                    ],
                  ),
                ),
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

/// macOS-style drag bar for the AI chat bubble — full-width, subtle handle.
class _AiBubbleDragBar extends StatelessWidget {
  const _AiBubbleDragBar({required this.onPanUpdate});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onPanUpdate: onPanUpdate,
    child: const SizedBox(
      height: 20,
      child: Center(child: _GrabHandle(width: 36)),
    ),
  );
}

/// macOS-style resize grip at bottom-right of the AI chat bubble.
class _AiBubbleResizeBar extends StatelessWidget {
  const _AiBubbleResizeBar({required this.onPanUpdate});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => Align(
    alignment: Alignment.bottomRight,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: const Padding(
        padding: EdgeInsets.only(right: 6, bottom: 4),
        child: Icon(Icons.drag_handle, size: 14, color: Color(0xFF94A3B8)),
      ),
    ),
  );
}

/// Rounded grab handle indicator.
class _GrabHandle extends StatelessWidget {
  const _GrabHandle({required this.width});

  final double width;

  @override
  Widget build(final BuildContext context) => Container(
    width: width,
    height: 4,
    decoration: BoxDecoration(
      color: const Color(0xFFCBD5E1),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}
