import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/store_model.dart';

/// Banner oscuro del modo edición, arriba del mapa: editando, avatar en camino
/// o producto en la mano.
class EditBanner extends StatelessWidget {
  const EditBanner({
    super.key,
    required this.carrying,
    required this.busy,
    required this.onDropCarry,
    required this.onFinish,
  });

  final StoreProduct? carrying;
  final bool busy;
  final VoidCallback onDropCarry;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final carried = carrying;
    final Widget content;
    final String key;
    if (carried != null && !busy) {
      key = 'carrying-${carried.id}';
      content = Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.lime,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppTheme.ink),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Llevas en la mano',
                  style: TextStyle(color: AppTheme.onNightMuted, fontSize: 15),
                ),
                Text(
                  carried.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              onDropCarry();
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
            ),
            child: const Text('Soltar'),
          ),
        ],
      );
    } else {
      key = busy ? 'busy' : 'idle';
      content = Row(
        children: [
          const SizedBox(width: 6),
          busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppTheme.lime,
                  ),
                )
              : Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppTheme.lime,
                    shape: BoxShape.circle,
                  ),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              busy ? 'El avatar va en camino…' : 'Editando el supermercado',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
            onPressed: onFinish,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
            ),
            child: const Text('Terminar'),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.night,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              boxShadow: AppTheme.cardShadow,
            ),
            child: AnimatedSize(
              duration: AppTheme.motion(context, AppTheme.medium),
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: AppTheme.motion(context, AppTheme.medium),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.center,
                  children: [...previous, ?current],
                ),
                child: KeyedSubtree(key: ValueKey(key), child: content),
              ),
            ),
          ),
        ),
        if (carried != null && !busy) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Text(
              'Toca un espacio verde para dejarlo',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
