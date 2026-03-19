import 'package:flutter/material.dart';

import '../bubble/bubble_callbacks.dart';
import '../common/rail_status_dot.dart';
import 'panel_callbacks.dart';
import 'panel_view_model.dart';

/// Panel rail (collapsed strip). Uses panel view model rail fields + callbacks.
class PanelRail extends StatelessWidget {
  const PanelRail({
    required this.viewModel,
    required this.callbacks,
    required this.bubbleCallbacks,
    super.key,
  });

  final PanelViewModel viewModel;
  final PanelCallbacks callbacks;
  final BubbleCallbacks bubbleCallbacks;

  @override
  Widget build(final BuildContext context) {
    final theme = viewModel.theme;
    final bg = theme != null
        ? (theme.statusColors['background'] ?? const Color(0xFFF8FAFC))
        : const Color(0xFFF8FAFC);
    final border = theme != null
        ? (theme.statusColors['border'] ?? const Color(0xFFE2E8F0))
        : const Color(0xFFE2E8F0);
    return Card(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: border),
      ),
      child: Semantics(
        identifier: 'live_edit_panel_rail',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                identifier: 'live_edit_panel_expand_button',
                button: true,
                child: IconButton(
                  tooltip: 'Expand inspector',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: callbacks.onExpand,
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
              if (viewModel.railBackendSwitcherChild != null)
                viewModel.railBackendSwitcherChild!
              else
                Text(
                  viewModel.railBackendLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: viewModel.railHasBackendChoice
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF64748B),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemCount: viewModel.railBubbleSummaries.length,
                  separatorBuilder: (final _, final _) =>
                      const SizedBox(height: 6),
                  itemBuilder: (final _, final index) {
                    final s = viewModel.railBubbleSummaries[index];
                    return RailStatusDot(
                      label: s.label,
                      statusLabel: s.statusLabel,
                      active: s.active,
                      targetDomain: s.targetDomain,
                      onTap: () =>
                          bubbleCallbacks.onSetActiveBubble(s.bubbleId),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
