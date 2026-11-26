import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Botón cuadrado blanco de 56 con borde: volver, cerrar, accesos.
class SmSquareButton extends StatelessWidget {
  const SmSquareButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.dark = false,
    this.size = 56,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Para cabeceras `night`: fondo transparente con borde claro.
  final bool dark;
  final double size;

  /// Fondo tintado sin borde (cerrar en hojas).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusM);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: dark
              ? Colors.transparent
              : filled
              ? AppTheme.background
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: filled
                ? BorderSide.none
                : BorderSide(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppTheme.border,
                    width: 1.5,
                  ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: ExcludeSemantics(
                child: Icon(
                  icon,
                  size: 24,
                  color: dark ? Colors.white : AppTheme.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Volver: botón cuadrado con flecha a la izquierda.
class SmBackButton extends StatelessWidget {
  const SmBackButton({
    super.key,
    this.onPressed,
    this.dark = false,
    this.tooltip = 'Volver',
  });

  final VoidCallback? onPressed;
  final bool dark;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return SmSquareButton(
      icon: Icons.chevron_left_rounded,
      tooltip: tooltip,
      dark: dark,
      onPressed: onPressed ?? () => Navigator.maybePop(context),
    );
  }
}

/// Botón principal lima de 58 a lo ancho.
class SmPrimaryButton extends StatelessWidget {
  const SmPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.dark = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;

  /// Variante `night` (asistente del admin).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        backgroundColor: dark ? AppTheme.night : null,
        foregroundColor: dark ? Colors.white : null,
      ),
      child: AnimatedSwitcher(
        duration: AppTheme.motion(context, AppTheme.fast),
        child: loading
            ? const SizedBox(
                key: ValueKey('loading'),
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: AppTheme.ink,
                ),
              )
            : Row(
                key: const ValueKey('label'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 24),
                    const SizedBox(width: 10),
                  ],
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 10),
                    Icon(trailingIcon, size: 24),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Chip con forma de píldora: blanco con borde, o verde con texto blanco al
/// elegirlo. Cambia de color con una transición corta.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dark = false,
    this.icon,
    this.trailingIcon,
    this.tinted = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Seleccionado en `night` en vez de verde (filtros de la lista de compras).
  final bool dark;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Fondo tint con texto verde (chip del supermercado en el asistente).
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? (dark ? AppTheme.night : AppTheme.green)
        : tinted
        ? AppTheme.tint
        : Colors.white;
    final foreground = selected
        ? Colors.white
        : tinted
        ? AppTheme.green
        : AppTheme.ink;
    final shape = StadiumBorder(
      side: selected || tinted
          ? BorderSide.none
          : const BorderSide(color: AppTheme.border, width: 1.5),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: AppTheme.motion(context, AppTheme.fast),
        decoration: ShapeDecoration(color: background, shape: shape),
        child: Material(
          color: Colors.transparent,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: foreground),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      Icon(trailingIcon, size: 20, color: foreground),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
