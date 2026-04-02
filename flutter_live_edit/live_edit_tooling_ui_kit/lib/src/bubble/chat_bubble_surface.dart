import 'dart:async';
import 'dart:math' as math;

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

    /// When set (typically host bubble height minus drag/resize), layouts the
    /// scrollable transcript and caps multiline input; grows with user resize.
    this.maxContentHeight,
    super.key,
  });

  final ChatBubbleViewModel viewModel;
  final ChatBubbleCallbacks callbacks;
  final bool autofocus;
  final double? maxContentHeight;

  @override
  State<ChatBubbleSurface> createState() => _ChatBubbleSurfaceState();
}

class _ChatBubbleSurfaceState extends State<ChatBubbleSurface> {
  late final TextEditingController _input;
  final _scrollController = ScrollController();
  bool _autoScrollQueued = false;

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
      _queueAutoScrollToEnd();
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
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF166534),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _buildPreviewBanner() => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFCD34D)),
    ),
    child: Text(
      widget.viewModel.previewSummary!,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF92400E),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );

  void _queueAutoScrollToEnd() {
    if (_autoScrollQueued) return;
    _autoScrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollQueued = false;
      _scrollToEnd();
    });
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    if ((max - position.pixels).abs() < 1) return;
    // Streaming can emit many timeline updates per second; jumpTo avoids
    // animation backlog that can lock the UI while a bubble is in progress.
    _scrollController.jumpTo(max);
  }

  void _handleSend() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    unawaited(widget.callbacks.onSend(text));
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
          if (vm.canApplyPreview)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                identifier: 'live_edit_preview_apply_button',
                button: true,
                child: _ApplyPreviewButton(onTap: cb.onApplyPreview),
              ),
            ),
          if (vm.canRollback)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                identifier: 'live_edit_rollback_button',
                button: true,
                child: _RollbackButton(onTap: cb.onRollback),
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

  List<ChatMessage> _visibleMessages() {
    final vm = widget.viewModel;
    return vm.showThinking
        ? vm.messages
        : vm.messages
              .where((final m) => m.role != ChatMessageRole.thinking)
              .toList(growable: false);
  }

  Widget _buildMessages({required final double maxHeight}) {
    final visible = _visibleMessages();
    if (visible.isEmpty) {
      return SizedBox(
        height: math.min(72, math.max(36, maxHeight)),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: math.max(48, maxHeight)),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: visible.length,
        itemBuilder: (_, final i) => ChatMessageTile(message: visible[i]),
      ),
    );
  }

  // ── Input bar ───────────────────────────────────────────────────────

  Widget _buildInputBar({
    required final double maxFieldHeight,
    required final int maxInputLines,
  }) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF0D9488),
                      width: 0.5,
                    ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxFieldHeight),
                  child: Semantics(
                    identifier: 'live_edit_ai_prompt_field',
                    child: TextField(
                      controller: _input,
                      autofocus: widget.autofocus,
                      enabled: !busy,
                      minLines: 1,
                      maxLines: maxInputLines,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
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
                          ),
                        ),
                      ),
                      onChanged: widget.callbacks.onInputChanged,
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Semantics(
                  identifier: 'live_edit_apply_button',
                  button: true,
                  child: _SendButton(busy: busy, onTap: _handleSend),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLaidOutContent(final double maxH) {
    final vm = widget.viewModel;
    final hasPreviewBanner = _hasText(vm.previewSummary);
    final hasAppliedBanner = _hasText(vm.appliedSummary);
    final hasBanner = hasPreviewBanner || hasAppliedBanner;
    const headerBlock = 46.0;
    const divider = 1.0;
    final bannerH = hasBanner ? 54.0 : 0.0;
    final applyExtra = (vm.canApplyAll && vm.applyAllCount > 0) ? 36.0 : 0.0;
    final fixedTop = headerBlock + divider + bannerH;
    final double inputFieldMax = math.min(132, math.max(44, maxH * 0.42));
    final int maxLines = math.min(8, math.max(1, (inputFieldMax / 21).floor()));
    final inputColumnH = inputFieldMax + applyExtra;
    double remaining = maxH - fixedTop - inputColumnH;
    if (remaining < 28) {
      remaining = 28;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildHeader(),
        const Divider(height: 1, thickness: 0.5, color: Color(0x18000000)),
        if (hasPreviewBanner)
          _buildPreviewBanner()
        else if (hasAppliedBanner)
          _buildAppliedBanner(),
        if (vm.showThinking)
          _buildMessages(maxHeight: remaining)
        else
          const SizedBox.shrink(),
        _buildInputBar(maxFieldHeight: inputFieldMax, maxInputLines: maxLines),
      ],
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(final BuildContext context) {
    final cap = widget.maxContentHeight;
    if (cap == null) {
      return Material(
        type: MaterialType.transparency,
        child: SizedBox(height: 260, child: _buildLaidOutContent(260)),
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (final context, final c) {
          final maxH = math.min(cap, c.maxHeight);
          return _buildLaidOutContent(maxH);
        },
      ),
    );
  }
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
        ),
      ),
    ),
  );
}

class _ApplyPreviewButton extends StatelessWidget {
  const _ApplyPreviewButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFCD34D).withOpacity(0.25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Apply',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF92400E),
        ),
      ),
    ),
  );
}

class _RollbackButton extends StatelessWidget {
  const _RollbackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFB91C1C).withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Rollback',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFB91C1C),
        ),
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
      decoration: const BoxDecoration(
        color: Color(0xFF94A3B8),
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
