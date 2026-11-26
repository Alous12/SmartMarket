import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Etiqueta compartida del logo entre login y registro.
const smLogoHeroTag = 'sm-logo';

/// Logo actual de SmartMarket en un cuadro redondeado, con [Hero].
class SmLogo extends StatelessWidget {
  const SmLogo({super.key, this.size = 104});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: smLogoHeroTag,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/images/smartmarket_logo.jpg',
          fit: BoxFit.cover,
          semanticLabel: 'Logo de SmartMarket',
        ),
      ),
    );
  }
}

/// Mensaje de error del servidor bajo el formulario.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space3),
      decoration: BoxDecoration(
        color: AppTheme.dangerTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
          const SizedBox(width: AppTheme.space2),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zona fija de abajo: botón principal y enlace secundario.
class AuthBottomActions extends StatelessWidget {
  const AuthBottomActions({
    super.key,
    required this.primary,
    required this.secondary,
  });

  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, const SizedBox(height: 8), secondary],
        ),
      ),
    );
  }
}

/// Ojo para mostrar u ocultar la contraseña.
class PasswordEye extends StatelessWidget {
  const PasswordEye({
    super.key,
    required this.obscured,
    required this.onPressed,
  });

  final bool obscured;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppTheme.muted,
      ),
    );
  }
}
