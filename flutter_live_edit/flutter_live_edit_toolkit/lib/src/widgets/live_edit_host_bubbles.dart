part of '../live_edit_host.dart';

class _AiBubbleBody extends StatelessWidget {
  const _AiBubbleBody({
    required this.context,
    required this.controller,
    this.bubbleId,
    this.autofocus = false,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final String? bubbleId;
  final bool autofocus;

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final stagedSummary = bubbleId != null
        ? selectStagedRequestSummaryForBubble(
            context,
            controller,
            bubbleId,
            presentationDomain: presentationDomain,
            sessionId: sessionId,
          )
        : selectStagedRequestSummary(
            context,
            controller,
            presentationDomain: presentationDomain,
            sessionId: sessionId,
          );
    final needsApprovalNow = bubbleId != null
        ? selectNeedsApprovalForBubble(context, bubbleId)
        : selectNeedsApproval(context);
    final plan = bubbleId != null
        ? selectExecutionPlanForBubble(context, bubbleId)
        : selectPendingExecutionPlan(context);
    final history = bubbleId != null
        ? selectHistoryForBubble(context, bubbleId)
        : selectHistoryForBubble(
            context,
            selectActiveBubbleId(
              context,
              controller,
              presentationDomain: presentationDomain,
              sessionId: sessionId,
            ),
          );
    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        _AgentActivityPanel(
          context: context,
          controller: controller,
          bubbleId: bubbleId,
        ),
        const SizedBox(height: 8),
        if (_hasText(stagedSummary) &&
            !needsApprovalNow &&
            context.bubbleResource.value.applyPhase !=
                LiveEditApplyPhase.success) ...<Widget>[
          PendingRequestCard(summary: stagedSummary!),
          const SizedBox(height: 10),
        ],
        if (plan case final planValue?)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  planValue.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(planValue.summary, style: const TextStyle(fontSize: 12)),
                if (planValue.requestedChanges.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  for (final change in planValue.requestedChanges)
                    Text('• $change', style: const TextStyle(fontSize: 12)),
                ],
                if (planValue.riskNotes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Warnings: ${planValue.riskNotes.join(' | ')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A3412),
                    ),
                  ),
                ],
              ],
            ),
          ),
        for (final entry in history.reversed.take(6))
          _TimelineBubble(entry: entry),
        const SizedBox(height: 8),
        _BubbleComposerSection(
          context: context,
          controller: controller,
          bubbleId: bubbleId,
          autofocus: autofocus,
        ),
        const SizedBox(height: 10),
        _ApplyActions(
          context: context,
          controller: controller,
          bubbleId: bubbleId,
          compact: true,
          semanticsPrefix: 'live_edit_bubble',
        ),
      ],
    );
  }
}

class _AiComposer extends StatefulWidget {
  const _AiComposer({
    required this.context,
    required this.controller,
    this.bubbleId,
    this.autofocus = false,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final String? bubbleId;
  final bool autofocus;

  @override
  State<_AiComposer> createState() => _AiComposerState();
}

class _AiComposerState extends State<_AiComposer> {
  late final TextEditingController _controller;

  String _composerText() => widget.bubbleId != null
      ? selectInstructionTextForBubble(widget.context, widget.bubbleId)
      : (widget.context.bubbleResource.value.globalComposerText);

  @override
  Widget build(final BuildContext buildContext) {
    final text = _composerText();
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    final presentationDomain = selectPresentedLayer(widget.context);
    final sessionId = widget.context.sessionResource.value.activeSessionId;
    final backendLabel = selectCurrentBackendLabel(
      widget.context,
      widget.controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          identifier: 'live_edit_ai_prompt_field',
          child: TextField(
            controller: _controller,
            autofocus: widget.autofocus,
            enableInteractiveSelection: true,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText: 'Talk to $backendLabel about this selected element',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (final value) {
              if (widget.bubbleId != null) {
                UpdateBubbleComposerCommand(
                  bubbleId: widget.bubbleId!,
                  value: value,
                ).execute(widget.context);
              } else {
                UpdateAiComposerCommand(value: value).execute(widget.context);
              }
            },
            onSubmitted: (_) async {
              if (widget.bubbleId != null) {
                await ApplyDraftForBubbleCommand(
                  bubbleId: widget.bubbleId!,
                  message: _composerText().trim().isNotEmpty
                      ? _composerText()
                      : null,
                  globalBackendId: widget
                      .context
                      .backendConfigResource
                      .value
                      .globalBackendId,
                ).execute(widget.context);
              } else {
                await SubmitAiPromptCommand(
                  controller: widget.controller,
                ).execute(widget.context);
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _composerText());
  }
}

class _AppliedBubbleBody extends StatelessWidget {
  const _AppliedBubbleBody({
    required this.context,
    required this.controller,
    this.bubbleId,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final String? bubbleId;

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final bubbleRecord = selectBubbleRecord(context, bubbleId);
    final summary = bubbleId != null
        ? ((bubbleRecord?.instructionText ?? '').trim().isNotEmpty
              ? 'Applied live-edit changes.'
              : null)
        : selectCurrentActivity(
            context,
            controller,
            presentationDomain: presentationDomain,
            sessionId: sessionId,
          )?.summary;
    final plan = bubbleId != null
        ? selectExecutionPlanForBubble(context, bubbleId)
        : selectPendingExecutionPlan(context);
    final filesSuffix = plan != null
        ? plan.affectedFiles.join(', ')
        : 'Source updated.';
    final summaryText =
        '${summary ?? 'Applied live-edit changes.'} $filesSuffix';
    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        Container(
          key: const ValueKey<String>('applied_bubble'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Text(
            summaryText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF166534),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 10),
        _BubbleComposerSection(
          context: context,
          controller: controller,
          bubbleId: bubbleId,
        ),
        const SizedBox(height: 10),
        _ApplyActions(
          context: context,
          controller: controller,
          bubbleId: bubbleId,
          compact: true,
          semanticsPrefix: 'live_edit_bubble',
        ),
      ],
    );
  }
}

class _ApplyActions extends StatelessWidget {
  const _ApplyActions({
    required this.context,
    required this.controller,
    this.bubbleId,
    this.compact = false,
    this.semanticsPrefix,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final String? bubbleId;
  final bool compact;
  final String? semanticsPrefix;

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final draftCount = bubbleId != null
        ? (selectBubbleRecord(context, bubbleId)?.draftChanges.length ?? 0)
        : selectDraftChangesForDomain(
            context,
            controller,
            domain: presentationDomain,
            sessionId: sessionId,
          ).length;
    final stagedSummary = bubbleId != null
        ? selectStagedRequestSummaryForBubble(
            context,
            controller,
            bubbleId,
            presentationDomain: presentationDomain,
            sessionId: sessionId,
          )
        : selectStagedRequestSummary(
            context,
            controller,
            presentationDomain: presentationDomain,
            sessionId: sessionId,
          );
    final busy = selectIsApplyingBusy(context);
    final canApply = bubbleId != null
        ? (selectCanTriggerApplyForBubble(
                context,
                controller,
                bubbleId,
                presentationDomain: presentationDomain,
                sessionId: sessionId,
              ) &&
              !busy)
        : (selectCanTriggerApply(
                context,
                controller,
                presentationDomain: presentationDomain,
                sessionId: sessionId,
              ) &&
              !busy);
    final buttons = _buttons(canApply, busy);
    final wrap = compact
        ? Wrap(spacing: 8, runSpacing: 8, children: buttons)
        : Row(
            children: <Widget>[
              for (
                var index = 0;
                index < buttons.length;
                index += 1
              ) ...<Widget>[
                Expanded(child: buttons[index]),
                if (index + 1 < buttons.length) const SizedBox(width: 8),
              ],
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Draft changes: $draftCount',
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
        ),
        if (_hasText(stagedSummary)) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            stagedSummary!,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        wrap,
      ],
    );
  }

  String _actionId(final String suffix) {
    final prefix = semanticsPrefix;
    if (_hasText(prefix)) {
      return '${prefix!}_$suffix';
    }
    return 'live_edit_$suffix';
  }

  List<Widget> _buttons(final bool canApply, final bool busy) {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final selection = selectSelectionForDomain(
      context,
      controller,
      domain: presentationDomain,
      sessionId: sessionId,
    );
    return <Widget>[
      Semantics(
        identifier: _actionId('discard_button'),
        button: true,
        child: OutlinedButton(
          onPressed: canApply
              ? () => UndoDraftCommand().execute(context)
              : null,
          child: const Text('Discard'),
        ),
      ),
      if (selectHasAgentBackedDrafts(
            context,
            controller,
            presentationDomain: presentationDomain,
            sessionId: sessionId,
          ) ||
          selectEditMode(context) == LiveEditEditMode.ai ||
          selection != null)
        OutlinedButton(
          onPressed: busy
              ? null
              : () => OpenAiBubbleCommand(defaultPrompt: '').execute(context),
          child: const Text('AI'),
        ),
      Semantics(
        identifier: _actionId('apply_button'),
        button: true,
        child: FilledButton(
          onPressed: !canApply
              ? null
              : () async {
                  if (bubbleId != null) {
                    final msg = selectInstructionTextForBubble(
                      context,
                      bubbleId,
                    ).trim();
                    await ApplyDraftForBubbleCommand(
                      bubbleId: bubbleId!,
                      message: msg.isNotEmpty ? msg : null,
                      globalBackendId:
                          context.backendConfigResource.value.globalBackendId,
                    ).execute(context);
                  } else {
                    final msg =
                        selectCanSubmitAiPrompt(
                          context,
                          controller,
                          presentationDomain: presentationDomain,
                          sessionId: sessionId,
                        )
                        ? selectInstructionTextForBubble(
                            context,
                            selectActiveBubbleId(
                              context,
                              controller,
                              presentationDomain: presentationDomain,
                              sessionId: sessionId,
                            ),
                          )
                        : null;
                    await ApplyDraftCommand(
                      message: msg,
                      globalBackendId:
                          context.backendConfigResource.value.globalBackendId,
                    ).execute(context);
                  }
                },
          child: Text(
            busy
                ? 'Working...'
                : _isSendLabel()
                ? 'Send'
                : 'Apply',
          ),
        ),
      ),
      if (selectCanApplyAllBubbles(context))
        Semantics(
          identifier: _actionId('apply_all_button'),
          button: true,
          child: OutlinedButton(
            onPressed: () => ApplyAllBubblesCommand().execute(context),
            child: Text('Apply all (${selectPendingBubbleCount(context)})'),
          ),
        ),
      if (selectCanResolveActiveBubble(
        context,
        controller,
        presentationDomain: presentationDomain,
        sessionId: sessionId,
      ))
        Semantics(
          identifier: _actionId('done_button'),
          button: true,
          child: FilledButton.tonal(
            onPressed: () => ResolveActiveBubbleCommand().execute(context),
            child: const Text('Done'),
          ),
        ),
    ];
  }

  bool _isSendLabel() {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    if (bubbleId != null) {
      final hasPrompt = selectInstructionTextForBubble(
        context,
        bubbleId,
      ).trim().isNotEmpty;
      final draftCount =
          selectBubbleRecord(context, bubbleId)?.draftChanges.length ?? 0;
      return hasPrompt && draftCount == 0;
    }
    return selectCanSubmitAiPrompt(
          context,
          controller,
          presentationDomain: presentationDomain,
          sessionId: sessionId,
        ) &&
        selectDraftChangesForDomain(
          context,
          controller,
          domain: presentationDomain,
          sessionId: sessionId,
        ).isEmpty;
  }
}

class _BubbleComposerSection extends StatelessWidget {
  const _BubbleComposerSection({
    required this.context,
    required this.controller,
    this.bubbleId,
    this.autofocus = false,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final String? bubbleId;
  final bool autofocus;

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final stagedSummary = bubbleId != null
        ? selectStagedRequestSummaryForBubble(
            context,
            controller,
            bubbleId,
            presentationDomain: presentationDomain,
            sessionId: sessionId,
          )
        : selectStagedRequestSummary(
            context,
            controller,
            presentationDomain: presentationDomain,
            sessionId: sessionId,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BackendSwitcher(
          context: context,
          controller: controller,
          bubble: true,
          bubbleId: bubbleId,
        ),
        const SizedBox(height: 6),
        _AiComposer(
          context: context,
          controller: controller,
          bubbleId: bubbleId,
          autofocus: autofocus,
        ),
        if (_hasText(stagedSummary)) ...<Widget>[
          const SizedBox(height: 8),
          PendingRequestCard(summary: stagedSummary!),
        ],
      ],
    );
  }
}

class _SelectionBubbleBody extends StatelessWidget {
  const _SelectionBubbleBody({
    required this.context,
    required this.controller,
    this.bubbleId,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final String? bubbleId;

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final stagedSummary = bubbleId != null
        ? selectStagedDraftSummaryForBubble(
            context,
            controller,
            bubbleId,
            presentationDomain: presentationDomain,
            sessionId: sessionId,
          )
        : selectStagedDraftSummary(
            context,
            controller,
            presentationDomain: presentationDomain,
            sessionId: sessionId,
          );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              stagedSummary ??
                  'Describe the change in plain English. Use the inspector on the right for detailed properties.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(height: 12),
          _BubbleComposerSection(
            context: context,
            controller: controller,
            bubbleId: bubbleId,
          ),
          const SizedBox(height: 12),
          _ApplyActions(
            context: context,
            controller: controller,
            bubbleId: bubbleId,
            compact: true,
            semanticsPrefix: 'live_edit_bubble',
          ),
        ],
      ),
    );
  }
}

class _TimelineBubble extends StatelessWidget {
  const _TimelineBubble({required this.entry, this.debug = false});

  final LiveEditTimelineEntry entry;
  final bool debug;

  @override
  Widget build(final BuildContext context) {
    final isAssistant = entry.role == 'assistant' || entry.role == 'debug';
    return Align(
      alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: entry.role == 'debug'
              ? const Color(0xFF111827)
              : isAssistant
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              entry.message,
              style: TextStyle(
                fontSize: 12,
                color: entry.role == 'debug' ? Colors.white : null,
              ),
            ),
            if (debug || entry.role == 'debug') ...<Widget>[
              const SizedBox(height: 4),
              Text(
                entry.timestamp.toLocal().toIso8601String(),
                style: TextStyle(
                  fontSize: 10,
                  color: entry.role == 'debug'
                      ? Colors.white70
                      : const Color(0xFF64748B),
                ),
              ),
            ],
            if (entry.details.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              for (final detail in entry.details.take(4))
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11,
                    color: entry.role == 'debug'
                        ? Colors.white70
                        : const Color(0xFF475569),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
