import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tarjeta blanca de SmartMarket: radio 20, borde suave y sombra opcional.
class SmCard extends StatelessWidget {
  const SmCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.space4),
    this.shadow = false,
    this.onTap,
    this.color = Colors.white,
    this.borderColor = AppTheme.border,
    this.borderWidth = 1,
    this.radius = AppTheme.radiusL,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool shadow;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: shadow ? AppTheme.cardShadow : null,
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
