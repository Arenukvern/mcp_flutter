import 'package:flutter/material.dart';

/// Deterministic dogfood screen for visual reconstruction / golden compare.
class VisualReconstructScreen extends StatelessWidget {
  const VisualReconstructScreen({super.key});

  static const Color _ink = Color(0xFF1A1A2E);
  static const Color _accent = Color(0xFF007AFF);
  static const Color _muted = Color(0xFF6B6B70);

  @override
  Widget build(final BuildContext context) {
    return Semantics(
      identifier: 'visual_reconstruct_root',
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          title: const Text('Visual reconstruct'),
          backgroundColor: const Color(0xFFFAFAFA),
          elevation: 0,
          foregroundColor: _ink,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  identifier: 'visual_reconstruct_marker',
                  child: Container(
                    width: 280,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          label: 'reconstruct-v1',
                          child: const Text(
                            'reconstruct-v1',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'visual dogfood fixture',
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
