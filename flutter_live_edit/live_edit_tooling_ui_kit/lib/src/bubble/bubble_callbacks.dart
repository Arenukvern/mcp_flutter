import 'package:flutter/material.dart';

/// Callbacks for bubble UI; host wires these to commands.
abstract interface class BubbleCallbacks {
  void onSetActiveBubble(String? bubbleId);
  void onApply(String? bubbleId);
  void onResolve(String? bubbleId);
  void onComposerChanged(String value);
  void onDragBubble(String bubbleId, Offset delta);
  void onResizeBubble(Size size);
  void onSubmitPrompt(String text);
  void onBackendChanged(String backendId);
  void onDragBubbleEnd(String bubbleId);
}
