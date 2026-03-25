part of '../host/core/live_edit_host.dart';

class _AiComposer extends StatefulWidget {
  const _AiComposer({
    required this.context,
    required this.controller,
    this.bubbleId,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final String? bubbleId;

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

class _BubbleComposerSection extends StatelessWidget {
  const _BubbleComposerSection({
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
        ),
        if (_hasText(stagedSummary)) ...<Widget>[
          const SizedBox(height: 8),
          PendingRequestCard(summary: stagedSummary!),
        ],
      ],
    );
  }
}
