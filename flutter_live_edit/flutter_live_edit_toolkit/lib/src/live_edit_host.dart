import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import 'commands/commands.dart';
import 'live_edit_backend_utils.dart';
import 'live_edit_context.dart';
import 'live_edit_controller_adapter.dart';
import 'live_edit_orchestrator.dart';
import 'live_edit_overlay_theme.dart';
import 'live_edit_scope.dart';
import 'live_edit_types.dart';
import 'selectors/live_edit_selectors.dart';

double mathMax(final double left, final double right) =>
    left > right ? left : right;

double mathMin(final double left, final double right) =>
    left < right ? left : right;

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

double _asDouble(final Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value') ?? 0;
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

Object? _coerceValueForProperty(
  final LiveEditPropertyDescriptor property,
  final String value,
) {
  switch (property.kind) {
    case LiveEditPropertyKind.integer:
      return int.tryParse(value) ?? property.value;
    case LiveEditPropertyKind.number:
      return double.tryParse(value) ?? property.value;
    case LiveEditPropertyKind.boolean:
      final normalized = value.toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    case LiveEditPropertyKind.string:
    case LiveEditPropertyKind.color:
    case LiveEditPropertyKind.enumValue:
    case LiveEditPropertyKind.edgeInsets:
    case LiveEditPropertyKind.alignment:
    case LiveEditPropertyKind.bounds:
    case LiveEditPropertyKind.object:
      return value;
  }
}

String _domainLabel(final LiveEditTargetDomain domain) => switch (domain) {
  LiveEditTargetDomain.appScene => 'App',
  LiveEditTargetDomain.toolScene => 'Tool',
};

void _drawDashedRect(final Canvas canvas, final Rect rect, final Paint paint) {
  const dash = 8.0;
  const gap = 4.0;
  for (double x = rect.left; x < rect.right; x += dash + gap) {
    canvas.drawLine(
      Offset(x, rect.top),
      Offset(mathMin(x + dash, rect.right), rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(x, rect.bottom),
      Offset(mathMin(x + dash, rect.right), rect.bottom),
      paint,
    );
  }
  for (double y = rect.top; y < rect.bottom; y += dash + gap) {
    canvas.drawLine(
      Offset(rect.left, y),
      Offset(rect.left, mathMin(y + dash, rect.bottom)),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, y),
      Offset(rect.right, mathMin(y + dash, rect.bottom)),
      paint,
    );
  }
}

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
  final panelWidth = mathMax(
    selectPanelWidth(ctx),
    overlayTheme.panelWidth(expanded: panelExpanded),
  );
  final panelHeight = mathMax(
    selectPanelHeight(ctx),
    panelSurfaceTheme.height ?? selectPanelHeight(ctx),
  );
  final panelOffset = selectPanelPlacement(ctx, viewport);
  return Rect.fromLTWH(panelOffset.dx, panelOffset.dy, panelWidth, panelHeight);
}

String _persistLabel(
  final LiveEditPropertyDescriptor property,
  final LiveEditContext ctx,
  final LiveEditController controller,
) => property.requiresAgentForPersistence
    ? selectCurrentBackendLabel(
        ctx,
        controller,
        presentationDomain: selectPresentedLayer(ctx),
      )
    : property.persistable
    ? 'Direct'
    : 'Preview only';

Color _previewColor(final LiveEditPropertyDescriptor property) {
  if (property.requiresAgentForPersistence) {
    return const Color(0xFF7C2D12);
  }
  if (property.canPreviewExactly) {
    return const Color(0xFF065F46);
  }
  return const Color(0xFF92400E);
}

String _previewLabel(final LiveEditPropertyDescriptor property) {
  if (property.requiresAgentForPersistence) {
    return 'AI only';
  }
  if (property.canPreviewExactly) {
    return 'Live';
  }
  return 'Preview';
}

String _semanticsId(final String value) => value
    .replaceAll(RegExp('[^a-zA-Z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '')
    .toLowerCase();

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

/// Builds the optional "Properties" panel section. When null, the panel
/// does not show direct property editing; when set (e.g. by
/// [LiveEditPropertyEditPlugin.buildPropertyPanelSection]), the returned
/// widget is shown under the "Properties" section title.
typedef LiveEditPropertyPanelSectionBuilder =
    Widget? Function(LiveEditContext context, LiveEditController controller);

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
    this.buildPropertyPanelSection,
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
  final LiveEditPropertyPanelSectionBuilder? buildPropertyPanelSection;
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
    this.buildPropertyPanelSection,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final Size viewportSize;
  final LiveEditPropertyPanelSectionBuilder? buildPropertyPanelSection;

  @override
  Widget build(final BuildContext buildContext) {
    final overlayTheme = LiveEditOverlayThemeModel.instance;
    final panelRect = _panelRectForViewport(
      ctx: context,
      overlayTheme: overlayTheme,
      viewport: viewportSize,
    );
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final pinned = selectPinnedBubbleSummaries(
      context,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    final expanded = selectExpandedBubbleSummaries(
      context,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ...pinned.map(
          (final summary) => _PinnedBubblePill(
            context: context,
            controller: controller,
            summary: summary,
            viewportSize: viewportSize,
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
            buildPropertyPanelSection: buildPropertyPanelSection,
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
          _PendingRequestCard(summary: stagedSummary!),
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

  String _composerText() {
    final presentationDomain = selectPresentedLayer(widget.context);
    final sessionId = widget.context.sessionResource.value.activeSessionId;
    return widget.bubbleId != null
        ? selectInstructionTextForBubble(widget.context, widget.bubbleId)
        : (widget.context.bubbleResource.value.globalComposerText);
  }

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

class _BackendSwitcher extends StatelessWidget {
  const _BackendSwitcher({
    required this.context,
    required this.controller,
    this.rail = false,
    this.bubble = false,
    this.bubbleId,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final bool rail;
  final bool bubble;
  final String? bubbleId;

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final backends = context.backendConfigResource.value.availableBackends;
    if (backends.length < 2) {
      return const SizedBox.shrink();
    }
    final selected = bubbleId != null
        ? (selectBackendIdForBubble(context, bubbleId) ??
              selectCurrentBackendId(
                context,
                controller,
                presentationDomain: presentationDomain,
                sessionId: sessionId,
              ))
        : selectCurrentBackendId(
            context,
            controller,
            presentationDomain: presentationDomain,
            sessionId: sessionId,
          );
    final backendLabel = selectCurrentBackendLabel(
      context,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    if (rail) {
      return PopupMenuButton<String>(
        tooltip: 'Select backend',
        onSelected: (final id) =>
            SetBackendCommand(backendId: id).execute(context),
        itemBuilder: (final _) => backends
            .map(
              (final backend) => PopupMenuItem<String>(
                value: backend.id,
                enabled: backend.available,
                child: Text(
                  backend.available
                      ? backend.label
                      : '${backend.label} offline',
                  style: TextStyle(
                    fontSize: 11,
                    color: backend.available
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                    fontWeight: backend.id == selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(growable: false),
        child: Semantics(
          identifier: 'live_edit_backend_switcher_rail',
          button: true,
          child: Container(
            width: 40,
            padding: LiveEditOverlayThemeModel.instance
                .styleFor(kLiveEditBackendSwitcherSurfaceId)
                .padding,
            decoration: BoxDecoration(
              color: LiveEditOverlayThemeModel.instance
                  .styleFor(kLiveEditBackendSwitcherSurfaceId)
                  .backgroundColor,
              borderRadius: BorderRadius.circular(
                LiveEditOverlayThemeModel.instance
                    .styleFor(kLiveEditBackendSwitcherSurfaceId)
                    .cornerRadius,
              ),
              border: Border.all(
                color: LiveEditOverlayThemeModel.instance
                    .styleFor(kLiveEditBackendSwitcherSurfaceId)
                    .borderColor,
              ),
            ),
            child: Column(
              children: <Widget>[
                const Icon(Icons.sync_alt, size: 14),
                const SizedBox(height: 4),
                Text(
                  backendLabel.isNotEmpty
                      ? backendLabel.substring(0, 1).toUpperCase()
                      : 'A',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (bubble) {
      return Semantics(
        identifier: 'live_edit_bubble_backend_switcher',
        child: Row(
          children: <Widget>[
            for (var index = 0; index < backends.length; index += 1)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == backends.length - 1 ? 0 : 6,
                  ),
                  child: ChoiceChip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      backends[index].label,
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: backends[index].id == selected,
                    onSelected: backends[index].available
                        ? (final value) {
                            if (value) {
                              if (bubbleId != null) {
                                SetBubbleBackendCommand(
                                  bubbleId: bubbleId!,
                                  backendId: backends[index].id,
                                ).execute(context);
                              } else {
                                SetBackendCommand(
                                  backendId: backends[index].id,
                                ).execute(context);
                              }
                            }
                          }
                        : null,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    final surfaceTheme = LiveEditOverlayThemeModel.instance.styleFor(
      kLiveEditBackendSwitcherSurfaceId,
    );
    final surfaceKey = LiveEditOverlayThemeModel.instance.keyFor(
      kLiveEditBackendSwitcherSurfaceId,
    );
    return KeyedSubtree(
      key: surfaceKey,
      child: Semantics(
        identifier: 'live_edit_backend_switcher',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Backend',
              style: TextStyle(
                color: rail ? Colors.white70 : const Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final backend in backends)
                  ChoiceChip(
                    label: Text(
                      backend.available
                          ? backend.label
                          : '${backend.label} offline',
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: backend.id == selected,
                    onSelected: backend.available
                        ? (final value) {
                            if (value) {
                              SetBackendCommand(
                                backendId: backend.id,
                              ).execute(context);
                            }
                          }
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
        _BackendSwitcher(
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
          _PendingRequestCard(summary: stagedSummary!),
        ],
      ],
    );
  }
}

class _BubbleDragHandle extends StatelessWidget {
  const _BubbleDragHandle({
    required this.alignment,
    required this.onPanUpdate,
    this.semanticsId = 'live_edit_bubble_drag_handle',
  });

  final Alignment alignment;
  final ValueChanged<DragUpdateDetails> onPanUpdate;
  final String semanticsId;

  @override
  Widget build(final BuildContext context) => Semantics(
    identifier: semanticsId,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: SizedBox(
        height: 12,
        child: Align(
          alignment: alignment,
          child: Container(
            width: 28,
            height: 3,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF94A3B8),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BubbleResizeHandle extends StatelessWidget {
  const _BubbleResizeHandle({required this.onPanUpdate});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onPanUpdate: onPanUpdate,
    child: const Padding(
      padding: EdgeInsets.only(top: 6, left: 6),
      child: Icon(Icons.open_in_full, size: 14, color: Color(0xFF64748B)),
    ),
  );
}

class _CycleCandidateIntent extends Intent {
  const _CycleCandidateIntent(this.delta);

  final int delta;
}

class _EditorPanelSurface extends StatelessWidget {
  const _EditorPanelSurface({
    required this.context,
    required this.controller,
    this.buildPropertyPanelSection,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final LiveEditPropertyPanelSectionBuilder? buildPropertyPanelSection;

  @override
  Widget build(final BuildContext buildContext) => Stack(
    children: <Widget>[
      Positioned.fill(
        child: _PanelSurface(
          context: context,
          controller: controller,
          buildPropertyPanelSection: buildPropertyPanelSection,
        ),
      ),
      Positioned(
        top: 6,
        left: 0,
        right: 0,
        child: _PanelDragHandle(
          onPanUpdate: (final details) =>
              DragPanelCommand(delta: details.delta).execute(context),
        ),
      ),
      Positioned(
        right: 6,
        bottom: 6,
        child: _PanelResizeHandle(
          onPanUpdate: (final details) => ResizePanelCommand(
            width: selectPanelWidth(context) + details.delta.dx,
            height: selectPanelHeight(context) + details.delta.dy,
          ).execute(context),
        ),
      ),
    ],
  );
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
        builder: (final _, final __) => _buildBody(
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
          builder: (final _, final __) =>
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
                      _LiveEditOverlay(
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
                            buildPropertyPanelSection:
                                widget.buildPropertyPanelSection,
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

class _HandleBar extends StatelessWidget {
  const _HandleBar({required this.width});

  final double width;

  @override
  Widget build(final BuildContext context) => Container(
    width: width,
    height: 3,
    decoration: BoxDecoration(
      color: const Color(0xFF94A3B8),
      borderRadius: BorderRadius.circular(999),
    ),
  );
}

class _HitTestExclusionScope extends SingleChildRenderObjectWidget {
  const _HitTestExclusionScope({
    required this.excludedRects,
    required super.child,
  });

  final List<Rect> excludedRects;

  @override
  RenderObject createRenderObject(final BuildContext context) =>
      _RenderHitTestExclusionScope(excludedRects);

  @override
  void updateRenderObject(
    final BuildContext context,
    final _RenderHitTestExclusionScope renderObject,
  ) {
    renderObject.excludedRects = excludedRects;
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

class _LiveEditOverlay extends StatefulWidget {
  const _LiveEditOverlay({
    required this.context,
    required this.controller,
    required this.contentKey,
    required this.targetDomain,
    required this.interactive,
    this.excludedRects = const <Rect>[],
    this.openBubbleOnSelect = false,
    this.orchestrator,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final GlobalKey contentKey;
  final LiveEditTargetDomain targetDomain;
  final bool interactive;
  final List<Rect> excludedRects;
  final bool openBubbleOnSelect;

  /// When non-null, overlay uses orchestrator for pointer actions (legacy).
  final LiveEditOrchestrator? orchestrator;

  @override
  State<_LiveEditOverlay> createState() => _LiveEditOverlayState();
}

class _LiveEditOverlayPainter extends CustomPainter {
  const _LiveEditOverlayPainter({
    required this.selection,
    required this.hoverSelection,
    required this.multiSelection,
    required this.marqueeRect,
    required this.deeperPickActive,
    required this.draftChanges,
  });

  final LiveEditSelection? selection;
  final LiveEditSelection? hoverSelection;
  final List<LiveEditSelection> multiSelection;
  final Rect? marqueeRect;
  final bool deeperPickActive;
  final List<LiveEditDraftChange> draftChanges;

  @override
  void paint(final Canvas canvas, final Size size) {
    _paintHover(canvas);
    _paintMultiSelection(canvas);
    _paintMarquee(canvas);
    final currentSelection = selection;
    if (currentSelection == null || currentSelection.bounds == null) {
      return;
    }

    final bounds = currentSelection.bounds!;
    final baseRect = Rect.fromLTRB(
      bounds.left,
      bounds.top,
      bounds.right,
      bounds.bottom,
    );
    final selectionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = deeperPickActive
          ? const Color(0xFF2563EB)
          : const Color(0xFF00A77F);
    canvas.drawRect(baseRect, selectionPaint);

    final ghostRect = _ghostRectFromDrafts(baseRect);
    if (ghostRect != null) {
      final ghostPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFF7A18);
      _drawDashedRect(canvas, ghostRect, ghostPaint);
    }

    final labelText = _buildLabelText();
    if (labelText.isEmpty) {
      return;
    }

    final paragraphBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(fontSize: 12, fontWeight: FontWeight.w600),
          )
          ..pushStyle(ui.TextStyle(color: const Color(0xFF111827)))
          ..addText(labelText);

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 260));
    final labelRect = Rect.fromLTWH(
      baseRect.left,
      mathMax(0, baseRect.top - paragraph.height - 10),
      paragraph.width + 12,
      paragraph.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(10)),
      Paint()..color = const Color(0xFFFDE68A),
    );
    canvas.drawParagraph(
      paragraph,
      Offset(labelRect.left + 6, labelRect.top + 4),
    );
  }

  @override
  bool shouldRepaint(final _LiveEditOverlayPainter oldDelegate) =>
      oldDelegate.selection != selection ||
      oldDelegate.hoverSelection != hoverSelection ||
      oldDelegate.multiSelection != multiSelection ||
      oldDelegate.marqueeRect != marqueeRect ||
      oldDelegate.deeperPickActive != deeperPickActive ||
      oldDelegate.draftChanges != draftChanges;

  String _buildLabelText() {
    if (draftChanges.isEmpty) {
      return '';
    }
    return draftChanges
        .map((final draft) => '${draft.propertyId}: ${draft.targetValue}')
        .join(' | ');
  }

  Rect? _ghostRectFromDrafts(final Rect baseRect) {
    double? width;
    double? height;
    for (final draft in draftChanges) {
      if (draft.propertyId == 'width') {
        width = _asDouble(draft.targetValue);
      } else if (draft.propertyId == 'height') {
        height = _asDouble(draft.targetValue);
      }
    }
    if (width == null && height == null) {
      return null;
    }
    return Rect.fromLTWH(
      baseRect.left,
      baseRect.top,
      width ?? baseRect.width,
      height ?? baseRect.height,
    );
  }

  void _paintHover(final Canvas canvas) {
    final hovered = hoverSelection?.bounds;
    if (hovered == null) {
      return;
    }
    final rect = Rect.fromLTRB(
      hovered.left,
      hovered.top,
      hovered.right,
      hovered.bottom,
    );
    canvas.drawRect(rect, Paint()..color = const Color(0x220EA5E9));
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = deeperPickActive
            ? const Color(0xFF2563EB)
            : const Color(0xFF0EA5E9),
    );
  }

  void _paintMarquee(final Canvas canvas) {
    final rect = marqueeRect;
    if (rect == null) {
      return;
    }
    canvas.drawRect(rect, Paint()..color = const Color(0x1A2563EB));
    _drawDashedRect(
      canvas,
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF2563EB),
    );
  }

  void _paintMultiSelection(final Canvas canvas) {
    if (multiSelection.length < 2) {
      return;
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFF97316);
    for (final selection in multiSelection) {
      final bounds = selection.bounds;
      if (bounds == null) {
        continue;
      }
      canvas.drawRect(
        Rect.fromLTRB(bounds.left, bounds.top, bounds.right, bounds.bottom),
        paint,
      );
    }
  }
}

class _LiveEditOverlayState extends State<_LiveEditOverlay> {
  static const double _dragThreshold = 8;
  Offset? _pointerDown;
  bool _dragging = false;

  String? get _sessionId =>
      widget.orchestrator?.context.sessionResource.value.activeSessionId ??
      widget.context.sessionResource.value.activeSessionId;

  List<LiveEditDraftChange> get _draftChangesForDomain =>
      widget.controller.draftChangesForDomain(
        targetDomain: widget.targetDomain,
        sessionId: _sessionId,
      );

  LiveEditSelection? get _hoverForDomain =>
      widget.controller.hoverSelectionForDomain(
        targetDomain: widget.targetDomain,
        sessionId: _sessionId,
      );

  Rect? get _marqueeRectForDomain => widget.controller.marqueeRectForDomain(
    targetDomain: widget.targetDomain,
    sessionId: _sessionId,
  );

  List<LiveEditSelection> get _marqueeSelectionsForDomain =>
      widget.controller.marqueeSelectionsForDomain(
        targetDomain: widget.targetDomain,
        sessionId: _sessionId,
      );

  List<LiveEditSelection> get _multiSelectionForDomain =>
      widget.controller.multiSelectionForDomain(
        targetDomain: widget.targetDomain,
        sessionId: _sessionId,
      );

  LiveEditSelection? get _selectionForDomain =>
      widget.controller.selectionForDomain(
        targetDomain: widget.targetDomain,
        sessionId: _sessionId,
      );

  bool get _deeperPickEnabled =>
      (widget.orchestrator?.context ?? widget.context)
          .panelViewResource
          .value
          .deeperPickEnabled;

  Element? get _contentRoot => widget.contentKey.currentContext is Element
      ? widget.contentKey.currentContext! as Element
      : null;

  @override
  Widget build(final BuildContext context) => Positioned.fill(
    child: _HitTestExclusionScope(
      excludedRects: widget.excludedRects,
      child: Focus(
        autofocus: true,
        child: MouseRegion(
          onHover: widget.interactive
              ? (final event) {
                  HoverAtPointCommand(
                    x: event.position.dx.round(),
                    y: event.position.dy.round(),
                    contentRoot: _contentRoot,
                    deeperMode: _deeperPickEnabled,
                    targetDomain: widget.targetDomain,
                  ).execute(widget.context);
                }
              : null,
          onExit: widget.interactive
              ? (_) => ClearHoverCommand().execute(widget.context)
              : null,
          child: IgnorePointer(
            ignoring: !widget.interactive,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (final event) {
                _pointerDown = event.position;
                _dragging = false;
                HoverAtPointCommand(
                  x: event.position.dx.round(),
                  y: event.position.dy.round(),
                  contentRoot: _contentRoot,
                  deeperMode: _deeperPickEnabled,
                  targetDomain: widget.targetDomain,
                ).execute(widget.context);
              },
              onPointerMove: (final event) {
                final start = _pointerDown;
                if (start == null) {
                  HoverAtPointCommand(
                    x: event.position.dx.round(),
                    y: event.position.dy.round(),
                    contentRoot: _contentRoot,
                    deeperMode: _deeperPickEnabled,
                    targetDomain: widget.targetDomain,
                  ).execute(widget.context);
                  return;
                }
                if (!_dragging &&
                    (event.position - start).distance >= _dragThreshold) {
                  _dragging = true;
                  StartMarqueeCommand(
                    x: start.dx.round(),
                    y: start.dy.round(),
                  ).execute(widget.context);
                }
                if (_dragging) {
                  UpdateMarqueeCommand(
                    x: event.position.dx.round(),
                    y: event.position.dy.round(),
                    contentRoot: _contentRoot,
                  ).execute(widget.context);
                  return;
                }
                HoverAtPointCommand(
                  x: event.position.dx.round(),
                  y: event.position.dy.round(),
                  contentRoot: _contentRoot,
                  deeperMode: _deeperPickEnabled,
                  targetDomain: widget.targetDomain,
                ).execute(widget.context);
              },
              onPointerUp: (final event) {
                if (_dragging) {
                  CommitMarqueeCommand(
                    controller: widget.controller,
                  ).execute(widget.context);
                } else {
                  SelectNodeCommand(
                    x: event.position.dx.round(),
                    y: event.position.dy.round(),
                    controller: widget.controller,
                    contentRoot: _contentRoot,
                    preferHoverPreview: _deeperPickEnabled,
                    targetDomain: widget.targetDomain,
                    openBubbleOnSelect: widget.openBubbleOnSelect,
                  ).execute(widget.context);
                }
                _pointerDown = null;
                _dragging = false;
              },
              onPointerCancel: (_) {
                if (_dragging) {
                  CancelMarqueeCommand().execute(widget.context);
                }
                _pointerDown = null;
                _dragging = false;
              },
              child: CustomPaint(
                painter: _LiveEditOverlayPainter(
                  selection: _selectionForDomain,
                  hoverSelection: _hoverForDomain,
                  multiSelection: _marqueeRectForDomain != null
                      ? _marqueeSelectionsForDomain
                      : _multiSelectionForDomain,
                  marqueeRect: _marqueeRectForDomain,
                  deeperPickActive: widget.interactive && _deeperPickEnabled,
                  draftChanges: _draftChangesForDomain,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NumericEditor extends StatefulWidget {
  const _NumericEditor({
    required this.context,
    required this.controller,
    required this.property,
    required this.surface,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;

  @override
  State<_NumericEditor> createState() => _NumericEditorState();
}

class _NumericEditorState extends State<_NumericEditor> {
  late final TextEditingController _controller;

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(widget.context);
    final sessionId = widget.context.sessionResource.value.activeSessionId;
    final text =
        '${selectEffectiveValueForProperty(widget.context, widget.controller, widget.property, presentationDomain: presentationDomain, sessionId: sessionId) ?? ''}';
    final waiting = selectIsPropertyWaiting(
      widget.context,
      widget.controller,
      widget.property,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return Row(
      children: <Widget>[
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 14,
          onPressed: waiting
              ? null
              : () => _applyDelta(-widget.property.numericStep),
          icon: const Icon(Icons.remove),
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: widget.surface == LiveEditEditSurface.inline,
            enableInteractiveSelection: true,
            enabled: !waiting,
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onSubmitted: _submit,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 14,
          onPressed: waiting
              ? null
              : () => _applyDelta(widget.property.numericStep),
          icon: const Icon(Icons.add),
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
    _controller = TextEditingController(text: '${widget.property.value ?? ''}');
  }

  void _applyDelta(final double delta) {
    final presentationDomain = selectPresentedLayer(widget.context);
    final sessionId = widget.context.sessionResource.value.activeSessionId;
    final base = _asDouble(
      selectEffectiveValueForProperty(
        widget.context,
        widget.controller,
        widget.property,
        presentationDomain: presentationDomain,
        sessionId: sessionId,
      ),
    );
    final next = base + delta;
    final targetValue = widget.property.kind == LiveEditPropertyKind.integer
        ? next.round()
        : next;
    UpdateDraftFromUiCommand(
      property: widget.property,
      targetValue: targetValue,
      surface: widget.surface,
    ).execute(widget.context);
  }

  void _submit(final String value) {
    UpdateDraftFromUiCommand(
      property: widget.property,
      targetValue: _coerceValueForProperty(widget.property, value.trim()),
      surface: widget.surface,
    ).execute(widget.context);
  }
}

class _PanelDragHandle extends StatelessWidget {
  const _PanelDragHandle({required this.onPanUpdate});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => Semantics(
    identifier: 'live_edit_panel_drag_handle',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: const SizedBox(
        height: 18,
        child: Center(child: _HandleBar(width: 34)),
      ),
    ),
  );
}

bool _hasBackendChoice(final LiveEditContext ctx) =>
    ctx.backendConfigResource.value.availableBackends.length > 1;

class _PanelRail extends StatelessWidget {
  const _PanelRail({
    required this.context,
    required this.controller,
    super.key,
  });

  final LiveEditContext context;
  final LiveEditController controller;

  @override
  Widget build(final BuildContext buildContext) {
    final theme = LiveEditOverlayThemeModel.instance.styleFor(
      kLiveEditPanelRailSurfaceId,
    );
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final activeSelection = selectSelectionForDomain(
      context,
      controller,
      domain: presentationDomain,
      sessionId: sessionId,
    );
    final activeBubbleId = selectActiveBubbleId(
      context,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    final bubbleStatus = selectBubbleStatusForBubble(context, activeBubbleId);
    return Card(
      color: theme.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.cornerRadius),
        side: BorderSide(color: theme.borderColor),
      ),
      child: Semantics(
        identifier: 'live_edit_panel_rail',
        child: Padding(
          padding: theme.padding,
          child: Column(
            children: <Widget>[
              Semantics(
                identifier: 'live_edit_panel_expand_button',
                button: true,
                child: IconButton(
                  tooltip: 'Expand inspector',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: () => ExpandPanelCommand().execute(context),
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
              Transform.scale(
                scale: 0.72,
                child: Switch(
                  value: selectDebugModeEnabled(context),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (final v) =>
                      SetDebugModeCommand(enabled: v).execute(context),
                ),
              ),
              Text(
                _hasBackendChoice(context)
                    ? selectCurrentBackendLabel(
                        context,
                        controller,
                        presentationDomain: presentationDomain,
                        sessionId: sessionId,
                      ).substring(0, 1).toUpperCase()
                    : 'DBG',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _hasBackendChoice(context)
                      ? const Color(0xFF1D4ED8)
                      : selectDebugModeEnabled(context)
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF64748B),
                ),
              ),
              if (_hasBackendChoice(context)) ...<Widget>[
                const SizedBox(height: 6),
                _BackendSwitcher(
                  context: context,
                  controller: controller,
                  rail: true,
                ),
              ],
              const SizedBox(height: 6),
              if (activeSelection != null)
                Column(
                  children: <Widget>[
                    _RailStatusDot(
                      label: activeSelection.widgetType,
                      status: bubbleStatus,
                      active: true,
                      targetDomain: selectTargetDomain(context),
                      onTap: () => SelectTrackedBubbleCommand(
                        bubbleId: activeBubbleId ?? activeSelection.nodeId,
                        controller: controller,
                      ).execute(context),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        selectCurrentActivity(
                              context,
                              controller,
                              presentationDomain: presentationDomain,
                              sessionId: sessionId,
                            )?.label ??
                            _bubbleStatusLabel(bubbleStatus),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemBuilder: (final _, final index) {
                    final summaries = selectBubbleSummaries(
                      context,
                      controller,
                      presentationDomain: presentationDomain,
                      sessionId: sessionId,
                    );
                    final summary = summaries[index];
                    return _RailStatusDot(
                      label: summary.label,
                      status: summary.status,
                      active: summary.active,
                      targetDomain: summary.targetDomain,
                      onTap: () => SelectTrackedBubbleCommand(
                        bubbleId: summary.bubbleId,
                        controller: controller,
                      ).execute(context),
                    );
                  },
                  separatorBuilder: (final _, final __) =>
                      const SizedBox(height: 6),
                  itemCount: selectBubbleSummaries(
                    context,
                    controller,
                    presentationDomain: presentationDomain,
                    sessionId: sessionId,
                  ).length,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelResizeHandle extends StatelessWidget {
  const _PanelResizeHandle({required this.onPanUpdate});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => Semantics(
    identifier: 'live_edit_panel_resize_handle',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: const Padding(
        padding: EdgeInsets.only(top: 6, left: 6),
        child: Icon(Icons.open_in_full, size: 14, color: Color(0xFF64748B)),
      ),
    ),
  );
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(final BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    ),
  );
}

class _PanelSurface extends StatelessWidget {
  const _PanelSurface({
    required this.context,
    required this.controller,
    this.buildPropertyPanelSection,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final LiveEditPropertyPanelSectionBuilder? buildPropertyPanelSection;

  @override
  Widget build(final BuildContext buildContext) {
    final panelExpanded = selectPanelExpanded(context);
    final surfaceId = panelExpanded
        ? kLiveEditPanelExpandedSurfaceId
        : kLiveEditPanelRailSurfaceId;
    return KeyedSubtree(
      key: LiveEditOverlayThemeModel.instance.keyFor(surfaceId),
      child: panelExpanded
          ? _PropertyPanel(
              key: const ValueKey<String>('expanded_panel'),
              context: context,
              controller: controller,
              buildPropertyPanelSection: buildPropertyPanelSection,
            )
          : _PanelRail(
              key: const ValueKey<String>('rail_panel'),
              context: context,
              controller: controller,
            ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({required this.summary});

  final String summary;

  @override
  Widget build(final BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFDE68A)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          'Pending request',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF92400E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          summary,
          style: const TextStyle(fontSize: 11, color: Color(0xFF78350F)),
        ),
      ],
    ),
  );
}

class _PinnedBubblePill extends StatelessWidget {
  const _PinnedBubblePill({
    required this.context,
    required this.controller,
    required this.summary,
    required this.viewportSize,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final LiveEditBubbleSummary summary;
  final Size viewportSize;

  @override
  Widget build(final BuildContext buildContext) {
    final bounds = summary.bounds;
    if (bounds == null) {
      return const SizedBox.shrink();
    }
    final left = mathMin(viewportSize.width - 28, mathMax(8, bounds.right + 6));
    final top = mathMin(viewportSize.height - 28, mathMax(8, bounds.top));
    return Positioned(
      left: left,
      top: top,
      child: Semantics(
        identifier: 'live_edit_pinned_bubble_${summary.nodeId}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => SelectTrackedBubbleCommand(
              bubbleId: summary.bubbleId,
              controller: controller,
            ).execute(context),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _bubbleStatusColor(summary.status),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PropertyActionColumn extends StatelessWidget {
  const _PropertyActionColumn({
    required this.context,
    required this.controller,
    required this.property,
    required this.surface,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;

  @override
  Widget build(final BuildContext buildContext) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      if (surface == LiveEditEditSurface.panel) ...<Widget>[
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          onPressed: () {
            if (property.requiresAgentForPersistence) {
              OpenAiBubbleCommand(
                property: property,
                defaultPrompt: '',
              ).execute(context);
            } else {
              FocusPropertyCommand(
                property: property,
                defaultPrompt: '',
              ).execute(context);
            }
          },
          icon: Icon(
            property.requiresAgentForPersistence
                ? Icons.smart_toy_outlined
                : Icons.ads_click_outlined,
          ),
        ),
      ],
    ],
  );
}

class _PropertyBadge extends StatelessWidget {
  const _PropertyBadge({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.captureSurfaceKey = false,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;
  final bool captureSurfaceKey;

  @override
  Widget build(final BuildContext context) {
    final theme = LiveEditOverlayThemeModel.instance.styleFor(
      kLiveEditStatusBadgeSurfaceId,
    );
    final badge = Container(
      padding: theme.padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(theme.cornerRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
    if (!captureSurfaceKey) {
      return badge;
    }
    return KeyedSubtree(
      key: LiveEditOverlayThemeModel.instance.keyFor(
        kLiveEditStatusBadgeSurfaceId,
      ),
      child: badge,
    );
  }
}

class _PropertyEditor extends StatelessWidget {
  const _PropertyEditor({
    required this.context,
    required this.controller,
    required this.property,
    required this.surface,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final waiting = selectIsPropertyWaiting(
      context,
      controller,
      property,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    if (!property.editable) {
      return Text(
        '${property.value ?? 'Not editable'}',
        style: const TextStyle(fontSize: 11),
      );
    }
    if (property.requiresAgentForPersistence &&
        surface == LiveEditEditSurface.inline) {
      return Row(
        children: <Widget>[
          const Expanded(
            child: Text('Use Apply', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            onPressed: () => OpenAiBubbleCommand(
              property: property,
              defaultPrompt: '',
            ).execute(context),
            child: const Text('AI', style: TextStyle(fontSize: 11)),
          ),
        ],
      );
    }

    if (property.kind == LiveEditPropertyKind.boolean) {
      final current =
          selectEffectiveValueForProperty(
            context,
            controller,
            property,
            presentationDomain: presentationDomain,
            sessionId: sessionId,
          ) ==
          true;
      return Align(
        alignment: Alignment.centerLeft,
        child: Switch(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          value: current,
          onChanged: waiting
              ? null
              : (final value) => UpdateDraftFromUiCommand(
                  property: property,
                  targetValue: value,
                  surface: surface,
                ).execute(context),
        ),
      );
    }

    if (property.options.isNotEmpty ||
        property.kind == LiveEditPropertyKind.enumValue) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: <Widget>[
          for (final option in property.options)
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: const TextStyle(fontSize: 11),
              label: Text(option),
              selected:
                  option ==
                  '${selectEffectiveValueForProperty(context, controller, property, presentationDomain: presentationDomain, sessionId: sessionId)}',
              onSelected: waiting
                  ? null
                  : (_) => UpdateDraftFromUiCommand(
                      property: property,
                      targetValue: option,
                      surface: surface,
                    ).execute(context),
            ),
        ],
      );
    }

    if (property.kind == LiveEditPropertyKind.integer ||
        property.kind == LiveEditPropertyKind.number) {
      return _NumericEditor(
        context: context,
        controller: controller,
        property: property,
        surface: surface,
      );
    }

    if (property.kind == LiveEditPropertyKind.string) {
      final multiline =
          property.prefersMultiline && surface == LiveEditEditSurface.panel;
      return _TextValueEditor(
        context: context,
        controller: controller,
        property: property,
        surface: surface,
        multiline: multiline,
      );
    }

    return Text(
      '${property.value ?? 'Unsupported inline editor'}',
      style: const TextStyle(fontSize: 12),
    );
  }
}

class _PropertyEditorCard extends StatelessWidget {
  const _PropertyEditorCard({
    required this.context,
    required this.controller,
    required this.property,
    required this.surface,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final rowTheme = LiveEditOverlayThemeModel.instance.styleFor(
      kLiveEditPropertyEditorRowSurfaceId,
    );
    final isActive =
        selectActivePropertyId(context, domain: presentationDomain) ==
        property.id;
    final disabled = !property.editable;
    final effectiveValue = selectEffectiveValueForProperty(
      context,
      controller,
      property,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );

    final cardChild = Ink(
      padding: rowTheme.padding,
      decoration: BoxDecoration(
        color: isActive ? rowTheme.backgroundColor : Colors.white,
        borderRadius: BorderRadius.circular(rowTheme.cornerRadius),
        border: Border.all(
          color: isActive ? const Color(0xFF0EA5E9) : rowTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: surface == LiveEditEditSurface.panel ? 78 : 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      property.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _propertySubtitle(property, effectiveValue),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF475569),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: rowTheme.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: <Widget>[
                        _PropertyBadge(
                          label: _previewLabel(property),
                          textColor: _previewColor(property),
                          backgroundColor: _previewColor(
                            property,
                          ).withOpacity(0.12),
                          captureSurfaceKey: isActive,
                        ),
                        _PropertyBadge(
                          label: _persistLabel(property, context, controller),
                          textColor: property.requiresAgentForPersistence
                              ? const Color(0xFF7C2D12)
                              : const Color(0xFF1D4ED8),
                          backgroundColor: property.requiresAgentForPersistence
                              ? const Color(0xFFFFEDD5)
                              : const Color(0xFFDBEAFE),
                        ),
                        if (selectHasDraftForProperty(
                          context,
                          controller,
                          property,
                          presentationDomain: presentationDomain,
                          sessionId: sessionId,
                        ))
                          _PropertyBadge(
                            label:
                                selectIsPropertyWaiting(
                                  context,
                                  controller,
                                  property,
                                  presentationDomain: presentationDomain,
                                  sessionId: sessionId,
                                )
                                ? 'Waiting'
                                : 'Dirty',
                            textColor:
                                selectIsPropertyWaiting(
                                  context,
                                  controller,
                                  property,
                                  presentationDomain: presentationDomain,
                                  sessionId: sessionId,
                                )
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF0F766E),
                            backgroundColor:
                                selectIsPropertyWaiting(
                                  context,
                                  controller,
                                  property,
                                  presentationDomain: presentationDomain,
                                  sessionId: sessionId,
                                )
                                ? const Color(0xFFDBEAFE)
                                : const Color(0xFFCCFBF1),
                          ),
                      ],
                    ),
                    SizedBox(height: rowTheme.gap),
                    if (surface == LiveEditEditSurface.panel)
                      Semantics(
                        identifier:
                            'live_edit_property_input_${_semanticsId(property.id)}',
                        child: _PropertyEditor(
                          context: context,
                          controller: controller,
                          property: property,
                          surface: surface,
                        ),
                      )
                    else
                      _PropertyEditor(
                        context: context,
                        controller: controller,
                        property: property,
                        surface: surface,
                      ),
                  ],
                ),
              ),
              SizedBox(width: rowTheme.gap),
              _PropertyActionColumn(
                context: context,
                controller: controller,
                property: property,
                surface: surface,
              ),
            ],
          ),
        ],
      ),
    );

    final card = InkWell(
      onTap: disabled
          ? null
          : () {
              if (surface == LiveEditEditSurface.aiBubble ||
                  property.requiresAgentForPersistence) {
                OpenAiBubbleCommand(
                  property: property,
                  defaultPrompt: '',
                ).execute(context);
              } else {
                FocusPropertyCommand(
                  property: property,
                  defaultPrompt: '',
                ).execute(context);
              }
            },
      borderRadius: BorderRadius.circular(14),
      child: surface == LiveEditEditSurface.panel
          ? Semantics(
              identifier: 'live_edit_property_${_semanticsId(property.id)}',
              child: cardChild,
            )
          : cardChild,
    );
    if (surface == LiveEditEditSurface.panel && isActive) {
      return KeyedSubtree(
        key: LiveEditOverlayThemeModel.instance.keyFor(
          kLiveEditPropertyEditorRowSurfaceId,
        ),
        child: card,
      );
    }
    return card;
  }

  String _propertySubtitle(
    final LiveEditPropertyDescriptor property,
    final Object? value,
  ) {
    final resolved = '$value'.isEmpty ? 'unset' : '$value';
    final editor = property.preferredEditor.isEmpty
        ? property.kind.wireName
        : property.preferredEditor;
    return '$resolved • $editor';
  }
}

class _PropertyPanel extends StatelessWidget {
  const _PropertyPanel({
    required this.context,
    required this.controller,
    this.buildPropertyPanelSection,
    super.key,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final LiveEditPropertyPanelSectionBuilder? buildPropertyPanelSection;

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
                          _BackendSwitcher(
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
                        _PanelSection(
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
                        _PanelSection(
                          title: 'Agent',
                          child: _InferenceConfigEditor(
                            context: context,
                            controller: controller,
                          ),
                        ),
                        _PanelSection(
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
                        _PanelSection(
                          title: 'Activity',
                          child: _AgentActivityPanel(
                            context: context,
                            controller: controller,
                            dense: true,
                          ),
                        ),
                        if (buildPropertyPanelSection != null)
                          _PanelSection(
                            title: 'Properties',
                            child:
                                buildPropertyPanelSection!(
                                  context,
                                  controller,
                                ) ??
                                const SizedBox.shrink(),
                          ),
                        _PanelSection(
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
                                _PendingRequestCard(
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
                          _PanelSection(
                            title: 'Prompt',
                            child: _SelectedPromptCard(
                              promptText: selectDebugPromptForActiveSelection(
                                context,
                                controller,
                                presentationDomain: presentationDomain,
                                sessionId: sessionId,
                              ),
                            ),
                          ),
                        if (selectDebugModeEnabled(context))
                          _PanelSection(
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

class _RailStatusDot extends StatelessWidget {
  const _RailStatusDot({
    required this.label,
    required this.status,
    required this.active,
    required this.targetDomain,
    required this.onTap,
  });

  final String label;
  final LiveEditBubbleStatus status;
  final bool active;
  final LiveEditTargetDomain targetDomain;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => Tooltip(
    message:
        '${_domainLabel(targetDomain)} • $label • ${_bubbleStatusLabel(status)}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _bubbleStatusColor(status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label.isEmpty ? '?' : label[0].toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _domainLabel(targetDomain)[0],
              style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RenderHitTestExclusionScope extends RenderProxyBox {
  _RenderHitTestExclusionScope(this._excludedRects);

  List<Rect> _excludedRects;

  set excludedRects(final List<Rect> value) {
    if (_excludedRects.length == value.length) {
      var changed = false;
      for (var index = 0; index < value.length; index += 1) {
        if (_excludedRects[index] != value[index]) {
          changed = true;
          break;
        }
      }
      if (!changed) {
        return;
      }
    }
    _excludedRects = value;
  }

  @override
  bool hitTest(
    final BoxHitTestResult result, {
    required final Offset position,
  }) {
    for (final rect in _excludedRects) {
      if (rect.contains(position)) {
        return false;
      }
    }
    return super.hitTest(result, position: position);
  }
}

class _SelectChildIntent extends Intent {
  const _SelectChildIntent();
}

class _SelectedPromptCard extends StatelessWidget {
  const _SelectedPromptCard({required this.promptText});

  final String? promptText;

  @override
  Widget build(final BuildContext context) {
    final hasPrompt = _hasText(promptText);
    return Semantics(
      identifier: 'live_edit_selected_prompt',
      child: ExpansionTile(
        key: const PageStorageKey<String>('live_edit_selected_prompt_tile'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text(
          'Agent request',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          hasPrompt
              ? 'Exact request sent to the agent for this bubble.'
              : 'No agent request sent for this bubble yet.',
          style: const TextStyle(fontSize: 10),
        ),
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SelectionArea(
              child: Text(
                hasPrompt
                    ? promptText!.trim()
                    : 'No agent request sent for this bubble yet.',
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ],
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
                          _BubbleDragHandle(
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
                                        ? '${selectMultiSelectionForDomain(context, controller, domain: presentationDomain, sessionId: sessionId).length} widgets • ${selectActiveProperty(context, controller, presentationDomain: presentationDomain, sessionId: sessionId)?.label ?? 'shared'}'
                                        : isActive &&
                                              selectHasMarqueePreview(
                                                context,
                                                controller,
                                                presentationDomain:
                                                    presentationDomain,
                                                sessionId: sessionId,
                                              )
                                        ? 'Drag selection preview • ${selectMarqueePreviewSelections(context, controller, presentationDomain: presentationDomain, sessionId: sessionId).length} hits'
                                        : '${selection?.widgetType ?? summary?.label ?? '?'} • ${isActive ? (selectActiveProperty(context, controller, presentationDomain: presentationDomain, sessionId: sessionId)?.label ?? 'node') : 'node'}',
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
                      child: _BubbleResizeHandle(
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

class _TextValueEditor extends StatefulWidget {
  const _TextValueEditor({
    required this.context,
    required this.controller,
    required this.property,
    required this.surface,
    required this.multiline,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;
  final bool multiline;

  @override
  State<_TextValueEditor> createState() => _TextValueEditorState();
}

class _TextValueEditorState extends State<_TextValueEditor> {
  late final TextEditingController _controller;

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(widget.context);
    final sessionId = widget.context.sessionResource.value.activeSessionId;
    final text =
        '${selectEffectiveValueForProperty(widget.context, widget.controller, widget.property, presentationDomain: presentationDomain, sessionId: sessionId) ?? ''}';
    final waiting = selectIsPropertyWaiting(
      widget.context,
      widget.controller,
      widget.property,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return TextField(
      controller: _controller,
      autofocus: widget.surface == LiveEditEditSurface.inline,
      enableInteractiveSelection: true,
      enabled: !waiting,
      maxLines: widget.multiline ? 4 : 1,
      minLines: widget.multiline ? 3 : 1,
      style: const TextStyle(fontSize: 11),
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        hintText: widget.multiline
            ? 'Edit value here without leaving the panel'
            : 'Edit inline',
      ),
      onChanged: (final value) {
        UpdateDraftFromUiCommand(
          property: widget.property,
          targetValue: _coerceValueForProperty(widget.property, value.trim()),
          surface: widget.surface,
        ).execute(widget.context);
      },
      onSubmitted: _submit,
      onEditingComplete: () => _submit(_controller.text),
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
    _controller = TextEditingController(text: '${widget.property.value ?? ''}');
  }

  void _submit(final String value) {
    UpdateDraftFromUiCommand(
      property: widget.property,
      targetValue: _coerceValueForProperty(widget.property, value.trim()),
      surface: widget.surface,
    ).execute(widget.context);
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
    final property = selectActiveProperty(
      context,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    final failure = status == LiveEditBubbleStatus.failed;
    final lastError = bubbleId != null
        ? selectLastErrorForBubble(context, bubbleId)
        : selectLastError(context);
    final record = selectBubbleRecord(context, bubbleId);
    final draftChanges = selectDraftChangesForDomain(
      context,
      controller,
      domain: presentationDomain,
      sessionId: sessionId,
    );
    final detailText = record != null
        ? (plan?.summary ??
              record.draftChanges
                  .map((final d) => '${d.propertyId}=${d.targetValue}')
                  .join(' • '))
        : (selectCurrentActivity(
                context,
                controller,
                presentationDomain: presentationDomain,
                sessionId: sessionId,
              )?.summary ??
              plan?.summary ??
              draftChanges
                  .map(
                    (final draft) => '${draft.propertyId}=${draft.targetValue}',
                  )
                  .join(' • '));
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
                          '$backendLabel is working on ${property?.label ?? 'this change'}.'),
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
