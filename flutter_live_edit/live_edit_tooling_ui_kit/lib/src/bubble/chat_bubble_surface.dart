import 'package:flutter/material.dart';

import 'chat_bubble_callbacks.dart';
import 'chat_bubble_view_model.dart';
import 'chat_message_tile.dart';

/// Minimal chat-style AI bubble. Three zones: header, messages, input.
class ChatBubbleSurface extends StatefulWidget {
  const ChatBubbleSurface({
    required this.viewModel,
    required this.callbacks,
    this.autofocus = false,
    super.key,
  });

  final ChatBubbleViewModel viewModel;
  final ChatBubbleCallbacks callbacks;
  final bool autofocus;

  @override
  State<ChatBubbleSurface> createState() => _ChatBubbleSurfaceState();
}

class _ChatBubbleSurfaceState extends State<ChatBubbleSurface> {
  late final TextEditingController _input;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.viewModel.inputText);
  }

  @override
  void didUpdateWidget(covariant final ChatBubbleSurface old) {
    super.didUpdateWidget(old);
    if (widget.viewModel.inputText != _input.text &&
        widget.viewModel.inputText != old.viewModel.inputText) {
      _input.value = TextEditingValue(
        text: widget.viewModel.inputText,
        selection: TextSelection.collapsed(
          offset: widget.viewModel.inputText.length,
        ),
      );
    }
    if (widget.viewModel.messages.length != old.viewModel.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  bool _hasText(final String? s) => s != null && s.trim().isNotEmpty;

  Widget _buildAppliedBanner() => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFECFDF5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFA7F3D0)),
    ),
    child: Text(
      widget.viewModel.appliedSummary!,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );

  void _scrollToEnd() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSend() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.callbacks.onSend(text);
    _input.clear();
    widget.callbacks.onInputChanged('');
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Header ──────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final vm = widget.viewModel;
    final cb = widget.callbacks;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
      child: Row(
        children: <Widget>[
          for (final b in vm.backends) ...<Widget>[
            _BackendTab(
              label: b.label,
              active: b.id == vm.activeBackendId,
              onTap: () => cb.onBackendChanged(b.id),
            ),
            if (b != vm.backends.last)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  '|',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
          ],
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => cb.onToggleThinking(!vm.showThinking),
            child: AnimatedOpacity(
              opacity: vm.showThinking ? 1.0 : 0.45,
              duration: const Duration(milliseconds: 150),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'thinking',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.1,
                      color: vm.showThinking
                          ? const Color(0xFF0D9488)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    vm.showThinking
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_outlined,
                    size: 13,
                    color: vm.showThinking
                        ? const Color(0xFF0D9488)
                        : const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (vm.draftCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Draft changes: ${vm.draftCount}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'No draft changes.',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
          if (vm.canDiscard)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                identifier: 'live_edit_discard_button',
                button: true,
                child: _DiscardButton(onTap: cb.onDiscard),
              ),
            ),
          _CollapseButton(onTap: cb.onCollapse),
          const SizedBox(width: 8),
          _DoneButton(onTap: cb.onDone),
        ],
      ),
    );
  }

  // ── Messages ────────────────────────────────────────────────────────

  Widget _buildMessages() {
    final vm = widget.viewModel;
    final visible = vm.showThinking
        ? vm.messages
        : vm.messages
              .where((final m) => m.role != ChatMessageRole.thinking)
              .toList(growable: false);
    if (visible.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Ask the agent to change this element.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
              letterSpacing: -0.1,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: visible.length,
      itemBuilder: (_, final i) => ChatMessageTile(message: visible[i]),
    );
  }

  // ── Input bar ───────────────────────────────────────────────────────

  Widget _buildInputBar() {
    final vm = widget.viewModel;
    final busy = vm.isBusy;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (vm.canApplyAll && vm.applyAllCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () => widget.callbacks.onApplyAll(vm.applyAllCount),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF0D9488), width: 0.5),
                  ),
                  child: Text(
                    'Apply all (${vm.applyAllCount})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: <Widget>[
          Expanded(
            child: Semantics(
              identifier: 'live_edit_ai_prompt_field',
              child: TextField(
                controller: _input,
              autofocus: widget.autofocus,
              enabled: !busy,
              maxLines: 1,
              style: const TextStyle(fontSize: 13, letterSpacing: -0.1),
              decoration: InputDecoration(
                hintText: 'ask changes..',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB0B8C4),
                  letterSpacing: -0.1,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                isDense: true,
                filled: true,
                fillColor: const Color(0x08000000),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: Color(0x18000000),
                    width: 0.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: Color(0xFF0D9488),
                    width: 1,
                  ),
                ),
              ),
              onChanged: widget.callbacks.onInputChanged,
              onSubmitted: (_) => _handleSend(),
            ),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            identifier: 'live_edit_apply_button',
            button: true,
            child: _SendButton(busy: busy, onTap: _handleSend),
          ),
        ],
      ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(final BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildHeader(),
        const Divider(height: 1, thickness: 0.5, color: Color(0x18000000)),
        if (_hasText(widget.viewModel.appliedSummary)) _buildAppliedBanner(),
        if (widget.viewModel.showThinking)
          Expanded(child: _buildMessages())
        else
          const SizedBox.shrink(),
        _buildInputBar(),
      ],
    ),
  );
}

// ── Small private sub-widgets ──────────────────────────────────────────

class _BackendTab extends StatelessWidget {
  const _BackendTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        letterSpacing: -0.2,
        color: active ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
        decoration: active ? TextDecoration.underline : TextDecoration.none,
        decorationColor: const Color(0xFF0F172A),
      ),
    ),
  );
}

class _DiscardButton extends StatelessWidget {
  const _DiscardButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF64748B).withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Discard',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
      ),
    ),
  );
}

class _CollapseButton extends StatelessWidget {
  const _CollapseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFF94A3B8),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.minimize_rounded, size: 15, color: Colors.white),
    ),
  );
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: Color(0xFF0D9488),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
    ),
  );
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => GestureDetector(
    onTap: busy ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: busy ? const Color(0xFFCBD5E1) : const Color(0xFF0D9488),
        shape: BoxShape.circle,
      ),
      child: busy
          ? const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            )
          : const Icon(
              Icons.arrow_upward_rounded,
              size: 16,
              color: Colors.white,
            ),
    ),
  );
}
