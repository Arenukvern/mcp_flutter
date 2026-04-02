/// Callbacks for the chat bubble; host wires these to commands.
abstract interface class ChatBubbleCallbacks {
  Future<void> onSend(final String text);
  void onInputChanged(final String value);
  void onBackendChanged(final String backendId);
  void onToggleThinking(final bool enabled);
  void onCollapse();
  void onDone();
  void onDiscard();
  void onApplyPreview();
  void onRollback();
  void onApplyAll(final int count);
}
