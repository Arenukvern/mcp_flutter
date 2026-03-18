import 'package:flutter/material.dart';

import '../commands/commands.dart';
import '../live_edit_context.dart';
import '../live_edit_controller_adapter.dart';
import '../live_edit_overlay_theme.dart';
import '../selectors/live_edit_selectors.dart';

class BackendSwitcher extends StatelessWidget {
  const BackendSwitcher({
    required this.context,
    required this.controller,
    super.key,
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
