import 'package:flutter/material.dart';

/// Section with title and child. Presentational only.
class PanelSection extends StatelessWidget {
  const PanelSection({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(final BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    ),
  );
}
