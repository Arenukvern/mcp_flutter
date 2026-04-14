part of '../host/core/live_edit_host.dart';

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
          if (selectDebugModeEnabled(context) && details.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            ExpansionTile(
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text(
                'Technical details',
                style: TextStyle(fontSize: 10, color: Color(0xFF334155)),
              ),
              children: <Widget>[
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
            ),
          ],
        ],
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

  @override
  Widget build(final BuildContext buildContext) {
    final theme = LiveEditOverlayThemeModel.instance.styleFor(
      kLiveEditPanelExpandedSurfaceId,
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
                  const Expanded(
                    child: Text(
                      'Live Edit',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
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
