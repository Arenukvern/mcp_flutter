/// Role of a chat message in the AI bubble conversation.
enum ChatMessageRole { user, assistant, thinking }

/// Single message in the chat bubble.
final class ChatMessage {
  const ChatMessage({required this.role, required this.text, this.timestamp});

  final ChatMessageRole role;
  final String text;
  final DateTime? timestamp;
}

/// Backend option for the chat bubble header selector.
typedef ChatBackendOption = ({String id, String label});

/// View model driving the chat bubble UI. Purely presentational.
final class ChatBubbleViewModel {
  const ChatBubbleViewModel({
    required this.messages,
    required this.backends,
    required this.activeBackendId,
    required this.showThinking,
    this.inputText = '',
    this.isBusy = false,
    this.canDiscard = false,
    this.canApplyAll = false,
    this.applyAllCount = 0,
    this.draftCount = 0,
    this.appliedSummary,
  });

  final List<ChatMessage> messages;
  final List<ChatBackendOption> backends;
  final String activeBackendId;
  final bool showThinking;
  final String inputText;
  final bool isBusy;
  final bool canDiscard;
  final bool canApplyAll;
  final int applyAllCount;
  final int draftCount;
  final String? appliedSummary;
}
