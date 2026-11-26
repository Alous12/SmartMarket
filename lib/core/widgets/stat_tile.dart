import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Número grande con su etiqueta. [dark] lo pinta para fondos `night`.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.helper,
    this.icon,
    this.dark = false,
    this.alert = false,
  });

  final String label;
  final String value;
  final String? helper;
  final IconData? icon;
  final bool dark;

  /// Resalta el valor como algo que requiere atención.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final background = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white;
    final labelColor = dark ? AppTheme.onNightMuted : AppTheme.muted;
    final valueColor = alert
        ? (dark ? const Color(0xFFFFC9A8) : AppTheme.warning)
        : (dark ? Colors.white : AppTheme.ink);
    return Container(
      padding: const EdgeInsets.all(AppTheme.space3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: dark ? null : Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: labelColor),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.1,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 2),
            Text(
              helper!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: labelColor, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
