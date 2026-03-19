part of '../live_edit_host.dart';

class _PropertyPanelBody extends StatelessWidget {
  const _PropertyPanelBody({required this.context, required this.controller});

  final LiveEditContext context;
  final LiveEditController controller;

  @override
  Widget build(final BuildContext buildContext) {
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final summaries = selectAllNonResolvedBubbleSummaries(
      context,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );

    if (summaries.isEmpty) {
      return const Center(
        child: Text(
          'Tap any widget in the app',
          style: TextStyle(fontSize: 11),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        PanelSection(
          title: 'Navigator',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final summary in summaries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _bubbleStatusColor(summary.status),
                      shape: BoxShape.circle,
                      border: summary.active
                          ? Border.all(color: Colors.white)
                          : null,
                    ),
                  ),
                  title: Text(
                    '${_domainLabel(summary.targetDomain)} • ${summary.label}'
                    '${summary.active ? ' • active' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: _hasText(summary.sourceLabel)
                      ? Text(
                          summary.sourceLabel!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  onTap: () => SelectTrackedBubbleCommand(
                    bubbleId: summary.bubbleId,
                    controller: controller,
                  ).execute(context),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
