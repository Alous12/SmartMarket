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

/// Tarjeta de instrucción: blanca cuando no hay ruta y verde oscuro, más
/// grande, mientras se sigue una ruta. [value] se muestra a la derecha.
class InstructionCard extends StatelessWidget {
  const InstructionCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.value,
    this.unit,
    this.icon = Icons.turn_right,
    this.navigating = false,
  });

  final String title;
  final String subtitle;
  final String? value;
  final String? unit;

  /// Maniobra que viene, como en un navegador.
  final IconData icon;

  /// Variante verde oscuro de la navegación.
  final bool navigating;

  @override
  Widget build(BuildContext context) {
    final duration = AppTheme.motion(context, AppTheme.medium);
    final ink = navigating ? Colors.white : AppTheme.ink;
    final muted = navigating ? const Color(0xFFDCEFD0) : AppTheme.muted;
    return Semantics(
      liveRegion: true,
      label: [
        title,
        subtitle,
        if (value != null) '$value ${unit ?? ''}',
      ].join('. '),
      child: AnimatedContainer(
        duration: duration,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: navigating ? AppTheme.green : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          boxShadow: AppTheme.cardShadow,
        ),
        child: ExcludeSemantics(
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.lime,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: AnimatedSwitcher(
                  duration: duration,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                    child: child,
                  ),
                  child: Icon(
                    icon,
                    key: ValueKey(icon),
                    size: 30,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Column(
                    // Cambia de tarjeta al cambiar de maniobra o de destino; la
                    // distancia que baja mientras se camina se actualiza sin más.
                    key: ValueKey('$icon|$subtitle'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: navigating ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: navigating ? 24 : 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value!,
                      style: TextStyle(
                        color: navigating ? AppTheme.lime : AppTheme.green,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    if (unit != null)
                      Text(unit!, style: TextStyle(color: muted, fontSize: 12)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón blanco cuadrado del mapa, con sombra.
class MapButton extends StatelessWidget {
  const MapButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.size = 58,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusL);
    return Semantics(
      button: true,
      child: Tooltip(
        message: tooltip,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: AppTheme.cardShadow,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: onPressed,
              child: SizedBox(
                width: size,
                height: size,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
