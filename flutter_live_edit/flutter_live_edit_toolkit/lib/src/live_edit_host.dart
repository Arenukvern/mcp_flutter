import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

import 'commands/commands.dart';
import 'live_edit_backend_utils.dart';
import 'live_edit_context.dart';
import 'live_edit_controller_adapter.dart';
import 'live_edit_host_overlay.dart';
import 'live_edit_orchestrator.dart';
import 'live_edit_overlay_theme.dart';
import 'live_edit_scope.dart';
import 'live_edit_tool_layer_glue.dart';
import 'live_edit_types.dart';
import 'selectors/live_edit_selectors.dart';
import 'widgets/backend_switcher.dart';

String _activityElapsedLabel(final LiveEditActivityEntry activity) {
  final elapsed = DateTime.now().toUtc().difference(activity.timestamp);
  if (elapsed.inSeconds < 5) {
    return activity.inProgress ? 'In progress' : 'Just now';
  }
  if (elapsed.inMinutes < 1) {
    return '${elapsed.inSeconds}s ago';
  }
  return '${elapsed.inMinutes}m ago';
}

String _basename(final String value) {
  final normalized = value.replaceAll(r'\', '/');
  final slashIndex = normalized.lastIndexOf('/');
  if (slashIndex < 0 || slashIndex + 1 >= normalized.length) {
    return normalized;
  }
  return normalized.substring(slashIndex + 1);
}

Color _bubbleStatusColor(final LiveEditBubbleStatus status) => switch (status) {
  LiveEditBubbleStatus.editing => const Color(0xFF0F766E),
  LiveEditBubbleStatus.waiting => const Color(0xFF1D4ED8),
  LiveEditBubbleStatus.needsApproval => const Color(0xFF92400E),
  LiveEditBubbleStatus.applied => const Color(0xFF166534),
  LiveEditBubbleStatus.failed => const Color(0xFFB91C1C),
};

String _bubbleStatusLabel(final LiveEditBubbleStatus status) =>
    switch (status) {
      LiveEditBubbleStatus.editing => 'Draft ready',
      LiveEditBubbleStatus.waiting => 'Applying',
      LiveEditBubbleStatus.needsApproval => 'Applying',
      LiveEditBubbleStatus.applied => 'Applied',
      LiveEditBubbleStatus.failed => 'Failed',
    };

String _domainLabel(final LiveEditTargetDomain domain) => switch (domain) {
  LiveEditTargetDomain.appScene => 'App',
  LiveEditTargetDomain.toolScene => 'Tool',
};

bool _hasText(final String? value) => value != null && value.trim().isNotEmpty;

Rect _panelRectForViewport({
  required final LiveEditContext ctx,
  required final LiveEditOverlayThemeModel overlayTheme,
  required final Size viewport,
}) {
  final panelExpanded = selectPanelExpanded(ctx);
  final panelSurfaceId = panelExpanded
      ? kLiveEditPanelExpandedSurfaceId
      : kLiveEditPanelRailSurfaceId;
  final panelSurfaceTheme = overlayTheme.styleFor(panelSurfaceId);
  final panelWidth = math.max(
    selectPanelWidth(ctx),
    overlayTheme.panelWidth(expanded: panelExpanded),
  );
  final panelHeight = math.max(
    selectPanelHeight(ctx),
    panelSurfaceTheme.height ?? selectPanelHeight(ctx),
  );
  final panelOffset = selectPanelPlacement(ctx, viewport);
  return Rect.fromLTWH(panelOffset.dx, panelOffset.dy, panelWidth, panelHeight);
}

String _sourceLocationLabel(
  final LiveEditSourceLocation? source, {
  final bool compact = false,
}) {
  if (source == null) {
    return '';
  }
  final file = source.file.trim();
  if (file.isNotEmpty) {
    final label = compact ? _basename(file) : file;
    if (source.line != null) {
      return '$label:${source.line}';
    }
    return label;
  }
  return source.sourceHint?.trim() ?? '';
}

class FlutterLiveEditHost extends StatefulWidget {
  const FlutterLiveEditHost({
    required this.child,
    super.key,
    this.controller,
    this.orchestrator,
    this.applyDraftDelegate,
    this.backendId,
    this.availableBackends = const <LiveEditAgentBackend>[],
    this.workingDirectory,
    this.intentText,
    this.childIsToolLayer = false,
  });

  final Widget child;
  final LiveEditController? controller;
  final LiveEditOrchestrator? orchestrator;
  final LiveEditApplyDraftDelegate? applyDraftDelegate;
  final String? backendId;
  final List<LiveEditAgentBackend> availableBackends;
  final String? workingDirectory;
  final String? intentText;
  final bool childIsToolLayer;

  @override
  State<FlutterLiveEditHost> createState() => _FlutterLiveEditHostState();
}

/// Reusable tool layer (pinned pills, expanded bubbles, panel) for the live-edit
/// overlay. Used by [FlutterLiveEditHost] and by [live_edit_tooling_ui_kit].
class LiveEditToolLayer extends StatelessWidget {
  const LiveEditToolLayer({
    required this.context,
    required this.controller,
    required this.viewportSize,
    super.key,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final Size viewportSize;

  @override
  Widget build(final BuildContext buildContext) {
    final overlayTheme = LiveEditOverlayThemeModel.instance;
    final panelRect = _panelRectForViewport(
      ctx: context,
      overlayTheme: overlayTheme,
      viewport: viewportSize,
    );
    final theme = buildToolingThemeData();
    final bubbleViewModel = buildBubbleLayerViewModel(
      context,
      controller,
      viewportSize,
      theme,
    );
    final panelViewModel = buildPanelViewModel(
      context,
      controller,
      viewportSize,
      theme,
    );
    final bubbleCallbacks = ToolLayerBubbleCallbacks(
      context: context,
      controller: controller,
    );
    final panelCallbacks = ToolLayerPanelCallbacks(context: context);
    final expanded = selectExpandedBubbleSummaries(
      context,
      controller,
      presentationDomain: selectPresentedLayer(context),
      sessionId: context.sessionResource.value.activeSessionId,
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ...bubbleViewModel.pinnedSummaries.map(
          (final summary) => PinnedBubblePill(
            summary: summary,
            viewportSize: viewportSize,
            callbacks: bubbleCallbacks,
            theme: bubbleViewModel.theme,
          ),
        ),
        ...expanded.map(
          (final summary) => _SelectionBubble(
            context: context,
            controller: controller,
            viewportSize: viewportSize,
            bubbleSummary: summary,
          ),
        ),
        Positioned(
          left: panelRect.left,
          top: panelRect.top,
          width: panelRect.width,
          height: panelRect.height,
          child: _EditorPanelSurface(
            context: context,
            controller: controller,
            railPanelViewModel: panelViewModel,
            panelCallbacks: panelCallbacks,
            bubbleCallbacks: bubbleCallbacks,
          ),
        ),
      ],
    );
  }
}

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

class _CycleCandidateIntent extends Intent {
  const _CycleCandidateIntent(this.delta);

  final int delta;
}

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

class _FlutterLiveEditHostState extends State<FlutterLiveEditHost> {
  LiveEditOrchestrator? _orchestrator;
  bool _ownsOrchestrator = false;
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _toolOverlayKey = GlobalKey();
  final LiveEditOverlayThemeModel _overlayTheme =
      LiveEditOverlayThemeModel.instance;

  bool get _editableTextHasPrimaryFocus {
    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    if (context == null) {
      return false;
    }
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null ||
        context.findAncestorStateOfType<EditableTextState>() != null;
  }

  @override
  Widget build(final BuildContext context) {
    if (_orchestrator != null) {
      return AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          _orchestrator!,
          _overlayTheme,
        ]),
        builder: (final _, final _) => _buildBody(
          context,
          _orchestrator!.context,
          _orchestrator!.controller,
        ),
      );
    }
    return Builder(
      builder: (final c) {
        final scope = LiveEditScope.maybeOf(c);
        assert(
          scope != null,
          'FlutterLiveEditHost requires LiveEditScope when orchestrator is null',
        );
        final data = scope!;
        return AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            data.sessionResource,
            data.selectionResource,
            data.draftResource,
            data.bubbleResource,
            data.panelViewResource,
            data.backendConfigResource,
            _overlayTheme,
          ]),
          builder: (final _, final _) =>
              _buildBody(c, data.context, data.controller),
        );
      },
    );
  }

  Widget _buildBody(
    final BuildContext context,
    final LiveEditContext ctx,
    final LiveEditController ctrl,
  ) => Shortcuts(
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowUp): _SelectParentIntent(),
      SingleActivator(LogicalKeyboardKey.arrowDown): _SelectChildIntent(),
      SingleActivator(LogicalKeyboardKey.arrowLeft): _CycleCandidateIntent(-1),
      SingleActivator(LogicalKeyboardKey.arrowRight): _CycleCandidateIntent(1),
    },
    child: Actions(
      actions: <Type, Action<Intent>>{
        _SelectParentIntent: CallbackAction<_SelectParentIntent>(
          onInvoke: (final _) {
            if (selectOverlayVisible(ctx) && !_editableTextHasPrimaryFocus) {
              SelectParentCandidateCommand(controller: ctrl).execute(ctx);
            }
            return null;
          },
        ),
        _SelectChildIntent: CallbackAction<_SelectChildIntent>(
          onInvoke: (final _) {
            if (selectOverlayVisible(ctx) && !_editableTextHasPrimaryFocus) {
              SelectChildCandidateCommand(controller: ctrl).execute(ctx);
            }
            return null;
          },
        ),
        _CycleCandidateIntent: CallbackAction<_CycleCandidateIntent>(
          onInvoke: (final intent) {
            if (selectOverlayVisible(ctx) && !_editableTextHasPrimaryFocus) {
              CycleSelectionCandidateCommand(
                controller: ctrl,
                delta: intent.delta,
              ).execute(ctx);
            }
            return null;
          },
        ),
      },
      child: Focus(
        autofocus: true,
        child: Overlay(
          initialEntries: <OverlayEntry>[
            OverlayEntry(
              builder: (final overlayContext) => LayoutBuilder(
                builder: (final _, final constraints) => Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    KeyedSubtree(key: _contentKey, child: widget.child),
                    if (selectOverlayVisible(ctx))
                      LiveEditOverlay(
                        context: ctx,
                        controller: ctrl,
                        contentKey: _contentKey,
                        targetDomain: LiveEditTargetDomain.appScene,
                        interactive: true,
                        openBubbleOnSelect: widget.childIsToolLayer,
                        orchestrator: _orchestrator,
                      ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: _LauncherChip(context: ctx, controller: ctrl),
                    ),
                    if (selectOverlayVisible(ctx) && !widget.childIsToolLayer)
                      Positioned.fill(
                        child: KeyedSubtree(
                          key: _toolOverlayKey,
                          child: LiveEditToolLayer(
                            context: ctx,
                            controller: ctrl,
                            viewportSize: constraints.biggest,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant final FlutterLiveEditHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_orchestrator == null) return;
    if (widget.availableBackends != oldWidget.availableBackends) {
      SetAvailableBackendsCommand(
        availableBackends: widget.availableBackends,
        initialBackendId:
            _orchestrator!.context.backendConfigResource.value.globalBackendId,
      ).execute(_orchestrator!.context);
    }
    if (_ownsOrchestrator &&
        widget.backendId != oldWidget.backendId &&
        widget.backendId != null) {
      SetBackendCommand(
        backendId: widget.backendId!,
      ).execute(_orchestrator!.context);
    }
  }

  @override
  void dispose() {
    if (_ownsOrchestrator && _orchestrator != null) {
      _orchestrator!.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.orchestrator != null) {
      _orchestrator = widget.orchestrator;
      _ownsOrchestrator = false;
    }
    // When orchestrator is null, host must be under LiveEditScope (checked in build).
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

class _PropertyPanel extends StatelessWidget {
  const _PropertyPanel({
    required this.context,
    required this.controller,
    super.key,
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
              child: selection == null
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
                                onChanged: (final v) => SetDeeperPickCommand(
                                  enabled: v,
                                ).execute(context),
                              ),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: <Widget>[
                                  for (final candidate
                                      in _visibleCandidates.indexed)
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
                                          final activeIdx = _visibleCandidates
                                              .indexWhere(
                                                (final c) => c.active,
                                              );
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
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Semantics(
                                      identifier:
                                          'live_edit_select_parent_button',
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
                                            ? () =>
                                                  SelectParentCandidateCommand(
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
                                  _hasText(
                                    _sourceLocationLabel(selection.source),
                                  )) ...<Widget>[
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
                                  !_hasText(
                                    _sourceLocationLabel(selection.source),
                                  )) ...<Widget>[
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
                    ),
            ),
          ],
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

class _SelectChildIntent extends Intent {
  const _SelectChildIntent();
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
    final bubbleHeight = pv.bubbleHeight;
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

class _SelectParentIntent extends Intent {
  const _SelectParentIntent();
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

class _WaitingBubbleBody extends StatelessWidget {
  const _WaitingBubbleBody({
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
    final activeBubbleId = selectActiveBubbleId(
      context,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    final status = bubbleId != null
        ? selectBubbleStatusForBubble(context, bubbleId)
        : selectBubbleStatusForBubble(context, activeBubbleId);
    final color = _bubbleStatusColor(status);
    final plan = bubbleId != null
        ? selectExecutionPlanForBubble(context, bubbleId)
        : selectPendingExecutionPlan(context);
    final failure = status == LiveEditBubbleStatus.failed;
    final lastError = bubbleId != null
        ? selectLastErrorForBubble(context, bubbleId)
        : selectLastError(context);
    final record = selectBubbleRecord(context, bubbleId);
    final detailText = record != null
        ? (plan?.summary ?? '')
        : (selectCurrentActivity(
                context,
                controller,
                presentationDomain: presentationDomain,
                sessionId: sessionId,
              )?.summary ??
              plan?.summary ??
              '');
    final backendLabel = selectCurrentBackendLabel(
      context,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        Container(
          key: ValueKey<String>('waiting_${status.name}'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                failure
                    ? (lastError ?? 'Agent request failed.')
                    : (selectCurrentActivity(
                            context,
                            controller,
                            presentationDomain: presentationDomain,
                            sessionId: sessionId,
                          )?.summary ??
                          '$backendLabel is working on this change.'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              _AgentActivityPanel(
                context: context,
                controller: controller,
                bubbleId: bubbleId,
              ),
              const SizedBox(height: 8),
              Text(
                detailText,
                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _BubbleComposerSection(
          context: context,
          controller: controller,
          bubbleId: bubbleId,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () => ExpandPanelCommand().execute(context),
                child: const Text('Inspector'),
              ),
            ),
            if (failure && bubbleId == null) ...<Widget>[
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () async {
                    OpenAiBubbleCommand(
                      defaultPrompt: selectDefaultAiPrompt(
                        context,
                        controller,
                        presentationDomain: presentationDomain,
                        sessionId: sessionId,
                      ),
                    ).execute(context);
                    await SubmitAiPromptCommand(
                      controller: controller,
                    ).execute(context);
                  },
                  child: const Text('Retry'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
