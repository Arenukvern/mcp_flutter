import 'package:flutter/material.dart';

/// Minimal theme data for tooling UI (bubble + panel). Supplied by the host
/// so ui_kit does not depend on toolkit overlay theme.
final class ToolingThemeData {
  const ToolingThemeData({
    required this.keyForSurface,
    this.statusColors = const {},
    this.statusLabels = const {},
  });

  /// Returns a [Key] for the given surface id (e.g. for semantics / overlay).
  final Key Function(String surfaceId) keyForSurface;

  /// Optional status -> color map (e.g. editing, waiting, applied, failed).
  final Map<String, Color> statusColors;

  /// Optional status -> label map.
  final Map<String, String> statusLabels;

  Color statusColor(final String status) =>
      statusColors[status] ?? const Color(0xFF0F766E);
  String statusLabel(final String status) => statusLabels[status] ?? status;
}
