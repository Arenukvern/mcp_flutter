import 'package:flutter/material.dart';
import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

import 'preview_fixtures.dart';

/// Dumb tool layer: bubble pills + panel rail built from fixture view models
/// and stub callbacks. No [LiveEditScope], no context, no commands.
/// Layer 1 – main surface for the playground.
class DumbToolLayer extends StatelessWidget {
  const DumbToolLayer({required this.viewportSize, super.key});

  final Size viewportSize;

  @override
  Widget build(final BuildContext context) {
    final bubbleViewModel = buildPreviewBubbleLayerViewModel(viewportSize);
    final panelRailViewModel = buildPreviewPanelRailViewModel(viewportSize);
    final panelExpandedViewModel = buildPreviewPanelExpandedViewModel(
      viewportSize,
    );
    final bubbleCallbacks = PreviewBubbleCallbacks();
    final panelCallbacks = PreviewPanelCallbacks();
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const _DummyClosedAiBubbleSurface(),
        const _DummyExpandedAiBubbleSurface(),
        ...bubbleViewModel.pinnedSummaries.map(
          (final summary) => PinnedBubblePill(
            summary: summary,
            viewportSize: viewportSize,
            callbacks: bubbleCallbacks,
            theme: bubbleViewModel.theme,
          ),
        ),
        Positioned(
          left: panelRailViewModel.placement.dx,
          top: panelRailViewModel.placement.dy,
          width: panelRailViewModel.width,
          height: panelRailViewModel.height,
          child: _DummyClosedPanelSurface(
            child: PanelRail(
              viewModel: panelRailViewModel,
              callbacks: panelCallbacks,
              bubbleCallbacks: bubbleCallbacks,
            ),
          ),
        ),
        Positioned(
          left: panelExpandedViewModel.placement.dx,
          top: panelExpandedViewModel.placement.dy,
          width: panelExpandedViewModel.width,
          height: panelExpandedViewModel.height,
          child: _DummyExpandedPanelSurface(
            child: PanelSurface(
              viewModel: panelExpandedViewModel,
              callbacks: panelCallbacks,
              bubbleCallbacks: bubbleCallbacks,
              expandedChild: const _DummyExpandedPanelCard(),
            ),
          ),
        ),
      ],
    );
  }
}

final class _DummyClosedAiBubbleSurface extends StatelessWidget {
  const _DummyClosedAiBubbleSurface();

  @override
  Widget build(final BuildContext context) => Positioned(
    left: 72,
    top: 84,
    child: Semantics(
      identifier: 'dummy_closed_ai_bubble',
      child: Container(
        width: 240,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'Closed AI bubble',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _DummyExpandedAiBubbleSurface extends StatelessWidget {
  const _DummyExpandedAiBubbleSurface();

  @override
  Widget build(final BuildContext context) => Positioned(
    left: 72,
    top: 168,
    width: 300,
    height: 144,
    child: Semantics(
      identifier: 'dummy_expanded_ai_bubble',
      child: Material(
        elevation: 4,
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCD34D)),
          ),
          child: Column(
            key: const ValueKey<String>('fixture:bubble:root'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                key: const ValueKey<String>('fixture:bubble:header'),
                children: <Widget>[
                  const Icon(
                    Icons.auto_awesome,
                    key: ValueKey<String>('fixture:bubble:header_icon'),
                    size: 16,
                    color: Color(0xFF92400E),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Expanded AI bubble',
                    key: ValueKey<String>('fixture:bubble:title'),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const Spacer(),
                  Container(
                    key: const ValueKey<String>('fixture:bubble:status_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE68A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Draft',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Prompt draft: Make panel compact and improve spacing.',
                key: ValueKey<String>('fixture:bubble:prompt'),
                style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 10),
              Wrap(
                key: const ValueKey<String>('fixture:bubble:chips'),
                spacing: 6,
                runSpacing: 6,
                children: const <Widget>[
                  Chip(
                    key: ValueKey<String>('fixture:bubble:chip_spacing'),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text('Spacing'),
                  ),
                  Chip(
                    key: ValueKey<String>('fixture:bubble:chip_radius'),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text('Radius'),
                  ),
                  Chip(
                    key: ValueKey<String>('fixture:bubble:chip_copy'),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text('Copy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final class _DummyClosedPanelSurface extends StatelessWidget {
  const _DummyClosedPanelSurface({required this.child});

  final Widget child;

  @override
  Widget build(final BuildContext context) =>
      Semantics(identifier: 'dummy_closed_panel', child: child);
}

final class _DummyExpandedPanelSurface extends StatelessWidget {
  const _DummyExpandedPanelSurface({required this.child});

  final Widget child;

  @override
  Widget build(final BuildContext context) =>
      Semantics(identifier: 'dummy_expanded_panel', child: child);
}

final class _DummyExpandedPanelCard extends StatelessWidget {
  const _DummyExpandedPanelCard();

  @override
  Widget build(final BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    child: Padding(
      key: const ValueKey<String>('fixture:panel:root'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            key: ValueKey<String>('fixture:panel:header'),
            children: <Widget>[
              Icon(
                Icons.tune,
                key: ValueKey<String>('fixture:panel:header_icon'),
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'Expanded panel',
                key: ValueKey<String>('fixture:panel:title'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Dummy panel body for live editing in app scene.',
            key: ValueKey<String>('fixture:panel:description'),
            style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 12),
          Container(
            key: const ValueKey<String>('fixture:panel:inspector_box'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Selection',
                  key: ValueKey<String>('fixture:panel:section_selection'),
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                ),
                SizedBox(height: 6),
                Text(
                  'dummy_expanded_panel',
                  key: ValueKey<String>('fixture:panel:selection_value'),
                  style: TextStyle(fontSize: 11, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            key: ValueKey<String>('fixture:panel:actions'),
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  key: ValueKey<String>('fixture:panel:button_reset'),
                  onPressed: null,
                  child: Text('Reset'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: ValueKey<String>('fixture:panel:button_apply'),
                  onPressed: null,
                  child: Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
