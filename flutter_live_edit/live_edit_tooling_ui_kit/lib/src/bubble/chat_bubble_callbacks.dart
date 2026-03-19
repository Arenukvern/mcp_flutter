/// Callbacks for the chat bubble; host wires these to commands.
abstract interface class ChatBubbleCallbacks {
  Future<void> onSend(String text);
  void onInputChanged(String value);
  void onBackendChanged(String backendId);
  void onToggleThinking(bool enabled);
  void onCollapse();
  void onDone();
  void onDiscard();
  void onApplyAll(int count);
}
