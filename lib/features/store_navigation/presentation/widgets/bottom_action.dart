import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class BottomAction extends StatelessWidget {
  const BottomAction({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.hint,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  /// Tarjeta opcional encima del botón.
  final Widget? hint;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hint != null) ...[hint!, const SizedBox(height: 10)],
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: AppTheme.cardShadow,
              ),
              child: FilledButton.icon(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                icon: Icon(icon, size: 26),
                label: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta pequeña sobre «Armar mi ruta» que invita a usar el asistente.
class AssistantHintCard extends StatelessWidget {
  const AssistantHintCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusXL);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.tint,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_outlined,
                    size: 22,
                    color: AppTheme.green,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    '¿Vas a cocinar algo? Arma la lista desde un plato',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmExit(BuildContext context) async {
  final exit = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.logout, color: AppTheme.green),
      title: const Text('¿Salir de SmartMarket?'),
      content: const Text('Puedes seguir explorando el supermercado.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Seguir explorando'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Salir'),
        ),
      ],
    ),
  );
  return exit == true;
}
