import 'package:flutter/material.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sm_buttons.dart';

/// «¡Listo! Tienes todo»: resumen al terminar la ruta.
class RouteCompleteView extends StatelessWidget {
  const RouteCompleteView({
    super.key,
    required this.collected,
    required this.total,
    required this.substitutes,
    required this.minutes,
    required this.estimate,
    required this.missing,
    required this.recipeName,
    required this.onRestart,
    required this.onFinish,
    this.onOpenHistory,
  });

  final int collected;
  final int total;
  final int substitutes;
  final int minutes;
  final double estimate;

  /// Ingredientes que no había en esta sucursal.
  final List<String> missing;

  /// Receta de la ruta, si vino del asistente.
  final String? recipeName;
  final VoidCallback onRestart;
  final VoidCallback onFinish;
  final VoidCallback? onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      color: AppTheme.background,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppTheme.green,
            padding: EdgeInsets.fromLTRB(24, top + 36, 24, 56),
            child: Column(
              children: [
                const _Badge(),
                const SizedBox(height: 22),
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: const Text(
                    '¡Listo! Tienes todo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  recipeName == null
                      ? 'Ya recogiste todos tus productos.'
                      : 'Ya recogiste todos los productos de tu ${recipeName!.toLowerCase()}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFDCEFD0),
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -26),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusXL + 4),
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 22, 18, 12),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _Stat(
                                  value: '$collected/$total',
                                  label: 'recogidos',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _Stat(
                                  value: '$substitutes',
                                  label: substitutes == 1
                                      ? 'sustituto'
                                      : 'sustitutos',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _Stat(
                                  value: '$minutes min',
                                  label: 'recorrido',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusL,
                              ),
                              border: Border.all(
                                color: AppTheme.border,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Line(
                                  label: 'Total estimado',
                                  value: formatBs(estimate),
                                ),
                                if (missing.isNotEmpty) ...[
                                  const Divider(height: 28),
                                  _Line(
                                    label: 'Falta en esta sucursal',
                                    value: missing.join(', '),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (recipeName != null) ...[
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: onOpenHistory,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(58),
                                disabledForegroundColor: AppTheme.ink,
                              ),
                              icon: const Icon(Icons.bookmark_border_rounded),
                              label: const Text(
                                'Queda en tu historial de recetas',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SmPrimaryButton(
                              label: 'Repetir ruta',
                              icon: Icons.replay_rounded,
                              onPressed: onRestart,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: onFinish,
                              child: const Text('Terminar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Círculo lima con el check: aparece con un rebote leve, una sola vez.
class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: AppTheme.motion(context, const Duration(milliseconds: 400)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        width: 108,
        height: 108,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 82,
          height: 82,
          decoration: const BoxDecoration(
            color: AppTheme.lime,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 46, color: AppTheme.ink),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.muted, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.muted, fontSize: 16),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
