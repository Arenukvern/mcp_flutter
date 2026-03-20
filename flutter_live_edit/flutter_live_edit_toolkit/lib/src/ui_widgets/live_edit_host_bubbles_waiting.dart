part of '../host/core/live_edit_host.dart';

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
