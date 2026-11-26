import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum StatusTone { ok, warning, danger, neutral }

/// Etiqueta redondeada de estado: Agotado, Stock bajo, Activo, Sustituto…
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.ok,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  (Color, Color) get _colors => switch (tone) {
    StatusTone.ok => (AppTheme.tint, AppTheme.green),
    StatusTone.warning => (AppTheme.warningTint, AppTheme.warning),
    StatusTone.danger => (AppTheme.dangerTint, AppTheme.danger),
    StatusTone.neutral => (AppTheme.track, AppTheme.ink),
  };

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
