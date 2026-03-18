part of '../live_edit_host.dart';

class _AgentActivityPanel extends StatelessWidget {
  const _AgentActivityPanel({
    required this.context,
    required this.controller,
    this.dense = false,
    this.bubbleId,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final bool dense;
  final String? bubbleId;

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    if (bubbleId != null) {
      final status = selectBubbleStatusForBubble(context, bubbleId);
      final summary = selectStagedRequestSummaryForBubble(
        context,
        controller,
        bubbleId,
        presentationDomain: presentationDomain,
        sessionId: sessionId,
      );
      final error = selectLastErrorForBubble(context, bubbleId);
      final hasPrompt = selectInstructionTextForBubble(
        context,
        bubbleId,
      ).trim().isNotEmpty;
      final label = hasPrompt ? 'Prompt ready' : _bubbleStatusLabel(status);
      final summaryText = summary ?? 'Draft changes for this bubble.';
      return Container(
        padding: EdgeInsets.all(dense ? 8 : 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D4ED8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              summaryText,
              style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (error != null && error.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                error,
                style: const TextStyle(fontSize: 10, color: Color(0xFF991B1B)),
                maxLines: dense ? 2 : 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      );
    }
    final latest = selectCurrentActivity(
      context,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    if (latest == null) {
      return Container(
        padding: EdgeInsets.all(dense ? 8 : 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'No activity yet.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      );
    }
    final details = latest.details.take(dense ? 2 : 4).toList(growable: false);
    return Container(
      padding: EdgeInsets.all(dense ? 8 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  latest.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
              Text(
                _activityElapsedLabel(latest),
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            latest.summary,
            style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
          ),
          if (selectLastError(context) case final error?) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              error,
              style: const TextStyle(fontSize: 10, color: Color(0xFF991B1B)),
              maxLines: dense ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (selectDebugModeEnabled(context) ||
              details.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            if (selectDebugModeEnabled(context))
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text(
                  'Technical details',
                  style: TextStyle(fontSize: 10, color: Color(0xFF334155)),
                ),
                children: <Widget>[
                  if (details.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'No technical details yet.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  for (final detail in details)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          detail,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                ],
              )
            else if (details.isNotEmpty)
              Text(
                details.first,
                style: const TextStyle(fontSize: 10, color: Color(0xFF334155)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ],
      ),
    );
  }
}

class _InferenceConfigEditor extends StatelessWidget {
  const _InferenceConfigEditor({
    required this.context,
    required this.controller,
  });

  final LiveEditContext context;
  final LiveEditController controller;

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final backend = selectCurrentBackend(
      context,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    if (backend == null) {
      return const Text(
        'No backend selected.',
        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      );
    }
    final model =
        selectCurrentModel(
          context,
          controller,
          presentationDomain: presentationDomain,
          sessionId: sessionId,
        ) ??
        '';
    final reasoning = selectCurrentReasoningEffort(
      context,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    final freeform = selectCurrentBackendUsesFreeformModel(
      context,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Backend: ${backend.label}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        if (freeform)
          Semantics(
            identifier: 'live_edit_model_input',
            child: TextFormField(
              key: ValueKey<String>('model-${backend.id}'),
              initialValue: model,
              decoration: const InputDecoration(
                labelText: 'Model',
                hintText: 'auto',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (final value) {
                SetInferenceConfigCommand(model: value).execute(context);
              },
            ),
          )
        else
          Semantics(
            identifier: 'live_edit_model_dropdown',
            child: DropdownButtonFormField<String>(
              initialValue: model.isEmpty ? null : model,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Model',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items:
                  selectCurrentSupportedModels(
                        context,
                        controller,
                        presentationDomain: presentationDomain,
                        sessionId: sessionId,
                      )
                      .map(
                        (final option) => DropdownMenuItem<String>(
                          value: option.id,
                          child: Text(
                            option.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(growable: false),
              onChanged: (final value) {
                if (value != null) {
                  SetInferenceConfigCommand(
                    model: value,
                    reasoningEffort: reasoning,
                  ).execute(context);
                }
              },
            ),
          ),
        if (!freeform) ...<Widget>[
          const SizedBox(height: 8),
          Semantics(
            identifier: 'live_edit_reasoning_dropdown',
            child: DropdownButtonFormField<String>(
              initialValue: reasoning,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Reasoning',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items:
                  selectCurrentSupportedReasoningEfforts(
                        context,
                        controller,
                        presentationDomain: presentationDomain,
                        sessionId: sessionId,
                      )
                      .map(
                        (final effort) => DropdownMenuItem<String>(
                          value: effort,
                          child: Text(
                            effort,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(growable: false),
              onChanged: (final value) {
                if (value != null) {
                  SetInferenceConfigCommand(
                    model: model,
                    reasoningEffort: value,
                  ).execute(context);
                }
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _PropertyPanel extends StatelessWidget {
  const _PropertyPanel({
    required this.context,
    required this.controller,
    super.key,
  });

  final LiveEditContext context;
  final LiveEditController controller;

  @override
  Widget build(final BuildContext buildContext) {
    final theme = LiveEditOverlayThemeModel.instance.styleFor(
      kLiveEditPanelExpandedSurfaceId,
    );
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final selection = selectSelectionForDomain(
      context,
      controller,
      domain: presentationDomain,
      sessionId: sessionId,
    );
    final error = selectLastError(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: theme.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.cornerRadius),
        side: BorderSide(color: theme.borderColor),
      ),
      child: Semantics(
        identifier: 'live_edit_panel',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Live Edit',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selection == null
                              ? 'Tap a widget'
                              : selectHasMultiSelection(
                                  context,
                                  controller,
                                  presentationDomain: presentationDomain,
                                  sessionId: sessionId,
                                )
                              ? '${selectMultiSelectionForDomain(context, controller, domain: presentationDomain, sessionId: sessionId).length} widgets • ${selectCurrentActivity(context, controller, presentationDomain: presentationDomain, sessionId: sessionId)?.label ?? _bubbleStatusLabel(selectBubbleStatusForBubble(context, selectActiveBubbleId(context, controller, presentationDomain: presentationDomain, sessionId: sessionId)))}'
                              : '${selection.widgetType} • ${selectCurrentActivity(context, controller, presentationDomain: presentationDomain, sessionId: sessionId)?.label ?? _bubbleStatusLabel(selectBubbleStatusForBubble(context, selectActiveBubbleId(context, controller, presentationDomain: presentationDomain, sessionId: sessionId)))}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (selectDebugModeEnabled(context) &&
                            _hasText(_sourceLocationLabel(selection?.source)))
                          Text(
                            _sourceLocationLabel(
                              selection?.source,
                              compact: true,
                            ),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (selectDebugModeEnabled(context) &&
                            !_hasText(_sourceLocationLabel(selection?.source)))
                          const Text(
                            'No concrete source context',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        if (context
                                .backendConfigResource
                                .value
                                .availableBackends
                                .length >
                            1) ...<Widget>[
                          const SizedBox(height: 6),
                          const SizedBox(height: 6),
                          BackendSwitcher(
                            context: context,
                            controller: controller,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.bug_report_outlined,
                        color: Colors.white70,
                        size: 14,
                      ),
                      Transform.scale(
                        scale: 0.72,
                        child: Switch(
                          value: selectDebugModeEnabled(context),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (final v) =>
                              SetDebugModeCommand(enabled: v).execute(context),
                        ),
                      ),
                    ],
                  ),
                  Semantics(
                    identifier: 'live_edit_panel_collapse_button',
                    button: true,
                    child: IconButton(
                      tooltip: 'Collapse inspector',
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      color: Colors.white,
                      onPressed: () => CollapsePanelCommand().execute(context),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ),
                ],
              ),
            ),
            if (_hasText(error))
              Container(
                color: const Color(0xFFFEF2F2),
                padding: const EdgeInsets.all(8),
                child: Text(
                  error!,
                  style: const TextStyle(
                    color: Color(0xFF991B1B),
                    fontSize: 11,
                  ),
                ),
              ),
            Expanded(
              child: _PropertyPanelBody(
                context: context,
                controller: controller,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
