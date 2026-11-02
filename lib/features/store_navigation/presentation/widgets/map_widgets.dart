import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/store_model.dart';

String locationOf(StoreProduct product) =>
    product.category.isEmpty ? 'la siguiente parada' : product.category;

class CenteredMessage extends StatelessWidget {
  const CenteredMessage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );
}

class InstructionCard extends StatelessWidget {
  const InstructionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.unit,
  });

  final String title;
  final String subtitle;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.lime,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.turn_right, size: 30, color: AppTheme.ink),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF6BB33F),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              Text(
                unit,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MapButton extends StatelessWidget {
  const MapButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
