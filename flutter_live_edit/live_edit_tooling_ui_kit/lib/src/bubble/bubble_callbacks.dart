import 'package:flutter/material.dart';

/// Callbacks for bubble UI; host wires these to commands.
abstract interface class BubbleCallbacks {
  void onSetActiveBubble(final String? bubbleId);
  void onApply(final String? bubbleId);
  void onResolve(final String? bubbleId);
  void onComposerChanged(final String value);
  void onDragBubble(final String bubbleId, final Offset delta);
  void onResizeBubble(final Size size);
  void onSubmitPrompt(final String text);
  void onBackendChanged(final String backendId);
  void onDragBubbleEnd(final String bubbleId);
}
