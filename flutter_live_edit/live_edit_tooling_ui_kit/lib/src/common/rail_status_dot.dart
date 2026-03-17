import 'package:flutter/material.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

/// Status dot for the panel rail list. Presentational only.
class RailStatusDot extends StatelessWidget {
  const RailStatusDot({
    required this.label,
    required this.statusLabel,
    required this.active,
    required this.targetDomain,
    required this.onTap,
    super.key,
  });

  final String label;
  final String statusLabel;
  final bool active;
  final LiveEditTargetDomain targetDomain;
  final VoidCallback onTap;

  static Color _statusColor(final String status) =>
      switch (status.toLowerCase()) {
        'editing' => const Color(0xFF0F766E),
        'waiting' => const Color(0xFF1D4ED8),
        'needsapproval' => const Color(0xFF92400E),
        'applied' => const Color(0xFF166534),
        'failed' => const Color(0xFFB91C1C),
        _ => const Color(0xFF0F766E),
      };

  @override
  Widget build(final BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
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
                border: active
                    ? Border.all(color: Colors.white, width: 1)
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
