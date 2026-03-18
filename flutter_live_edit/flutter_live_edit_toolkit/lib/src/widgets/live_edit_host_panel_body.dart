part of '../live_edit_host.dart';

class _PropertyPanelBody extends StatelessWidget {
  const _PropertyPanelBody({
    required this.context,
    required this.controller,
  });

  final LiveEditContext context;
  final LiveEditController controller;

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
    final selection = selectSelectionForDomain(
      context,
      controller,
      domain: presentationDomain,
      sessionId: sessionId,
    );

    return selection == null
        ? const Center(
            child: Text(
              'Tap any widget in the app',
              style: TextStyle(fontSize: 11),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(8),
            children: <Widget>[
              PanelSection(
                title: 'Navigator',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final summary in selectBubbleSummaries(
                      context,
                      controller,
                      presentationDomain: presentationDomain,
                      sessionId: sessionId,
                    ))
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        avatar: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _bubbleStatusColor(summary.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: Text(
                          summary.active
                              ? '${_domainLabel(summary.targetDomain)} • ${summary.label} • active'
                              : '${_domainLabel(summary.targetDomain)} • ${summary.label}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => SelectTrackedBubbleCommand(
                          bubbleId: summary.bubbleId,
                          controller: controller,
                        ).execute(context),
                      ),
                  ],
                ),
              ),
              PanelSection(
                title: 'Agent',
                child: _InferenceConfigEditor(
                  context: context,
                  controller: controller,
                ),
              ),
              PanelSection(
                title: 'Selection',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Deeper pick',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: selectDeeperPickEnabled(context),
                      onChanged: (final v) =>
                          SetDeeperPickCommand(enabled: v).execute(context),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final candidate in _visibleCandidates.indexed)
                          Semantics(
                            identifier:
                                'live_edit_candidate_chip_${candidate.$1}',
                            child: ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              label: Text(
                                _candidateLabel(candidate.$1),
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: candidate.$2.active,
                              onSelected: (_) {
                                final activeIdx = _visibleCandidates.indexWhere(
                                  (final c) => c.active,
                                );
                                if (activeIdx < 0) return;
                                final len = _visibleCandidates.length;
                                final delta =
                                    (candidate.$1 - activeIdx + len) % len;
                                if (delta == 0) return;
                                CycleSelectionCandidateCommand(
                                  controller: controller,
                                  delta: delta,
                                ).execute(context);
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Semantics(
                            identifier: 'live_edit_select_parent_button',
                            button: true,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: _visibleCandidates.length > 1
                                  ? () => SelectParentCandidateCommand(
                                      controller: controller,
                                    ).execute(context)
                                  : null,
                              icon: const Icon(
                                Icons.arrow_upward,
                                size: 14,
                              ),
                              label: const Text(
                                'Parent',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                            ),
                            onPressed: _visibleCandidates.length > 1
                                ? () => SelectChildCandidateCommand(
                                    controller: controller,
                                  ).execute(context)
                                : null,
                            icon: const Icon(
                              Icons.arrow_downward,
                              size: 14,
                            ),
                            label: const Text(
                              'Child',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (selectDebugModeEnabled(context) &&
                        _hasText(_sourceLocationLabel(selection.source))) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'Code: ${_sourceLocationLabel(selection.source)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_hasText(selection.source?.sourceHint))
                        Text(
                          selection.source!.sourceHint!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                    if (selectDebugModeEnabled(context) &&
                        !_hasText(_sourceLocationLabel(selection.source))) ...<Widget>[
                      const SizedBox(height: 6),
                      const Text(
                        'Code: No concrete source context',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PanelSection(
                title: 'Activity',
                child: _AgentActivityPanel(
                  context: context,
                  controller: controller,
                  dense: true,
                ),
              ),
              PanelSection(
                title: 'Thread',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _AiComposer(
                      context: context,
                      controller: controller,
                    ),
                    if (_hasText(
                      selectStagedRequestSummary(
                        context,
                        controller,
                        presentationDomain: presentationDomain,
                        sessionId: sessionId,
                      ),
                    )) ...<Widget>[
                      const SizedBox(height: 6),
                      PendingRequestCard(
                        summary: selectStagedRequestSummary(
                          context,
                          controller,
                          presentationDomain: presentationDomain,
                          sessionId: sessionId,
                        )!,
                      ),
                    ],
                    const SizedBox(height: 6),
                    for (final entry in selectHistoryForBubble(
                      context,
                      selectActiveBubbleId(
                        context,
                        controller,
                        presentationDomain: presentationDomain,
                        sessionId: sessionId,
                      ),
                    ).reversed.take(5))
                      _TimelineBubble(entry: entry),
                  ],
                ),
              ),
              if (selectDebugModeEnabled(context))
                PanelSection(
                  title: 'Prompt',
                  child: SelectedPromptCard(
                    promptText: selectDebugPromptForActiveSelection(
                      context,
                      controller,
                      presentationDomain: presentationDomain,
                      sessionId: sessionId,
                    ),
                  ),
                ),
              if (selectDebugModeEnabled(context))
                PanelSection(
                  title: 'Debug Log',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final entry
                          in selectDebugTimelineForActiveSelection(
                            context,
                            controller,
                            presentationDomain: presentationDomain,
                            sessionId: sessionId,
                          ).reversed.take(10))
                        _TimelineBubble(entry: entry, debug: true),
                    ],
                  ),
                ),
            ],
          );
  }

  String _candidateLabel(final int index) => switch (index) {
    0 => 'Selected',
    1 => 'Parent',
    2 => 'Child',
    _ => 'Alt ${index + 1}',
  };
}
