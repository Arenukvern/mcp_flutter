import 'package:flutter/material.dart';

import 'chat_bubble_view_model.dart';

/// Single chat message tile. User messages align right, others left.
class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(final BuildContext context) {
    final isUser = message.role == ChatMessageRole.user;
    final isThinking = message.role == ChatMessageRole.thinking;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF0D9488).withValues(alpha: 0.10)
              : isThinking
              ? const Color(0x08000000)
              : const Color(0x0C000000),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isUser ? 12 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 12),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            letterSpacing: -0.1,
            fontStyle: isThinking ? FontStyle.italic : FontStyle.normal,
            color: isThinking
                ? const Color(0xFF94A3B8)
                : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}
