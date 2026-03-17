import 'package:flutter/material.dart';

/// Card showing a pending request summary. Presentational only.
class PendingRequestCard extends StatelessWidget {
  const PendingRequestCard({required this.summary, super.key});

  final String summary;

  @override
  Widget build(final BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFDE68A)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          'Pending request',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF92400E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          summary,
          style: const TextStyle(fontSize: 11, color: Color(0xFF78350F)),
        ),
      ],
    ),
  );
}
