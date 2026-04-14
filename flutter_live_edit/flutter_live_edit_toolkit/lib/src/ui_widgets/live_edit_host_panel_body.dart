part of '../host/core/live_edit_host.dart';

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

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        PanelSection(
          title: 'Agent',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BackendSwitcher(context: context, controller: controller),
              const SizedBox(height: 8),
              if (selectCurrentBackendUsesFreeformModel(
                context,
                controller,
                presentationDomain: presentationDomain,
                sessionId: sessionId,
              ))
                Semantics(
                  identifier: 'live_edit_model_input',
                  child: TextFormField(
                    initialValue:
                        selectCurrentModel(
                          context,
                          controller,
                          presentationDomain: presentationDomain,
                          sessionId: sessionId,
                        ) ??
                        'auto',
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Model',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (final value) {
                      SetInferenceConfigCommand(model: value).execute(context);
                    },
                  ),
                )
              else ...<Widget>[
                Semantics(
                  identifier: 'live_edit_model_dropdown',
                  child: DropdownButtonFormField<String>(
                    initialValue: selectCurrentModel(
                      context,
                      controller,
                      presentationDomain: presentationDomain,
                      sessionId: sessionId,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Model',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        selectCurrentSupportedModels(
                              context,
                              controller,
                              presentationDomain: presentationDomain,
                              sessionId: sessionId,
                            )
                            .map((final model) => DropdownMenuItem<String>(
                                value: model.id,
                                child: Text(model.label),
                              ))
                            .toList(growable: false),
                    onChanged: (final value) {
                      SetInferenceConfigCommand(model: value).execute(context);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  identifier: 'live_edit_reasoning_dropdown',
                  child: DropdownButtonFormField<String>(
                    initialValue: selectCurrentReasoningEffort(
                      context,
                      controller,
                      presentationDomain: presentationDomain,
                      sessionId: sessionId,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Reasoning',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        selectCurrentSupportedReasoningEfforts(
                              context,
                              controller,
                              presentationDomain: presentationDomain,
                              sessionId: sessionId,
                            )
                            .map((final effort) => DropdownMenuItem<String>(
                                value: effort,
                                child: Text(effort),
                              ))
                            .toList(growable: false),
                    onChanged: (final value) {
                      SetInferenceConfigCommand(
                        reasoningEffort: value,
                      ).execute(context);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        PanelSection(
          title: 'Navigator',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (summaries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Tap any widget in the app',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
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
