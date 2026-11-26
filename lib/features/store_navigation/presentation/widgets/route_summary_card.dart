import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/store_model.dart';
import '../../domain/services/store_route_planner.dart';

/// Píldora blanca de la ruta en curso: cuántos productos van listos, metros
/// del recorrido y pasos detectados.
class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({
    super.key,
    required this.plan,
    required this.nameOf,
    required this.onClear,
    this.steps = 0,
    this.collected = 0,
  });

  final StoreRoutePlan plan;
  final String Function(StoreProduct product) nameOf;
  final VoidCallback onClear;

  /// Pasos detectados: muestra si los sensores están registrando la caminata.
  final int steps;

  /// Productos ya recogidos.
  final int collected;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppTheme.ink,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    final total = plan.products.length;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: AppTheme.motion(context, AppTheme.slow),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Text(
                '$collected de $total listos',
                key: ValueKey(collected),
                style: style,
              ),
            ),
            Text(' · ${plan.distance.round()} m', style: style),
            Flexible(
              child: Text(
                ' · $steps pasos',
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
