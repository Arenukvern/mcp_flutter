import 'package:flutter/material.dart';

/// Card showing the selected agent prompt. Presentational only.
class SelectedPromptCard extends StatelessWidget {
  const SelectedPromptCard({required this.promptText, super.key});

  final String? promptText;

  static bool _hasText(final String? s) => s != null && s.trim().isNotEmpty;

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
