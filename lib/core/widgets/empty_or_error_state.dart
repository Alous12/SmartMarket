import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Estado vacío o de error: icono en un cuadro tintado de 88, título grande,
/// explicación y, si hay [onRetry], el botón lima «Reintentar».
class EmptyOrErrorState extends StatelessWidget {
  const EmptyOrErrorState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.wifi_off_rounded,
    this.onRetry,
    this.error = true,
    this.compact = false,
  });

  final String title;
  final String? message;
  final IconData icon;
  final VoidCallback? onRetry;
  final bool error;

  /// Versión en fila, para dentro de una tarjeta o un mensaje.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tint = error ? AppTheme.dangerTint : AppTheme.tint;
    final color = error ? AppTheme.danger : AppTheme.green;
    if (compact) {
      return Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (message != null)
                  Text(
                    message!,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 14),
                  ),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              ),
              child: Icon(icon, color: color, size: 40),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                height: 1.25,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 17,
                  height: 1.45,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 64),
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 26),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
