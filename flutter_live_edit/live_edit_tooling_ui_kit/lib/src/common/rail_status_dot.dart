import 'package:flutter/material.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

/// Status dot for the panel rail list. Presentational only.
/// [compact] true: vertical rail style (dot, letter, domain initial).
/// [tooltipMessage] when set, wraps content in [Tooltip].
class RailStatusDot extends StatelessWidget {
  const RailStatusDot({
    required this.label,
    required this.statusLabel,
    required this.active,
    required this.targetDomain,
    required this.onTap,
    this.tooltipMessage,
    this.compact = false,
    super.key,
  });

  final String label;
  final String statusLabel;
  final bool active;
  final LiveEditTargetDomain targetDomain;
  final VoidCallback onTap;
  final String? tooltipMessage;
  final bool compact;

  static Color _statusColor(final String status) =>
      switch (status.toLowerCase()) {
        'editing' => const Color(0xFF0F766E),
        'waiting' => const Color(0xFF1D4ED8),
        'needsapproval' => const Color(0xFF92400E),
        'applied' => const Color(0xFF166534),
        'failed' => const Color(0xFFB91C1C),
        _ => const Color(0xFF0F766E),
      };

  static String _domainInitial(final LiveEditTargetDomain d) => switch (d) {
    LiveEditTargetDomain.appScene => 'A',
    LiveEditTargetDomain.toolScene => 'T',
  };

  @override
  Widget build(final BuildContext context) {
    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 10 : 4),
        child: compact ? _buildCompact() : _buildHorizontal(),
      ),
    );
    if (tooltipMessage != null && tooltipMessage!.isNotEmpty) {
      return Tooltip(message: tooltipMessage!, child: content);
    }
    return content;
  }

  Widget _buildHorizontal() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _statusColor(statusLabel),
            shape: BoxShape.circle,
            border: active ? Border.all(color: Colors.white, width: 1) : null,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _buildCompact() => Container(
    width: 40,
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: active ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: active ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0),
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _statusColor(statusLabel),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.isEmpty ? '?' : label[0].toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          _domainInitial(targetDomain),
          style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
        ),
      ],
    ),
  );
}
