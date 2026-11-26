import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sm_buttons.dart';

/// «Antes de caminar»: pide pararse en la entrada antes de seguir los pasos.
/// Devuelve true para seguir los pasos, false para ver solo la ruta, o null
/// si el usuario vuelve atrás.
class BeforeWalkingScreen extends StatelessWidget {
  const BeforeWalkingScreen({super.key, required this.storeName});

  final String storeName;

  /// Abre la pantalla encima de todo (sin barra inferior).
  static Future<bool?> open(BuildContext context, String storeName) {
    return Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => BeforeWalkingScreen(storeName: storeName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Row(
                children: [
                  const SmBackButton(),
                  Expanded(
                    child: Text(
                      storeName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _EntranceIllustration(),
                    const SizedBox(height: 32),
                    Semantics(
                      header: true,
                      child: const Text(
                        'Párate en la entrada',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Desde ahí seguimos tus pasos para mover tu muñeco por el mapa.',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 17,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final (index, step) in const [
                      'Mira hacia el interior de la tienda',
                      'Sostén el teléfono frente a ti',
                      'Camina a tu ritmo normal',
                    ].indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppTheme.tint,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusS,
                                ),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: AppTheme.green,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                step,
                                style: const TextStyle(
                                  color: AppTheme.ink,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusL),
                        border: Border.all(color: AppTheme.border, width: 1.5),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: AppTheme.green,
                            size: 24,
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Solo usamos el acelerómetro y la brújula. No usamos GPS ni guardamos tu recorrido.',
                              style: TextStyle(
                                color: AppTheme.ink,
                                fontSize: 16,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SmPrimaryButton(
                    label: 'Ya estoy en la entrada',
                    onPressed: () => Navigator.pop(context, true),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Ver solo la ruta, sin seguimiento'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entrada vista desde arriba: puertas lima y el punto donde pararse.
class _EntranceIllustration extends StatelessWidget {
  const _EntranceIllustration();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        height: 212,
        decoration: BoxDecoration(
          color: AppTheme.green,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned(
              left: 18,
              top: 18,
              child: Text(
                'ENTRADA PRINCIPAL',
                style: TextStyle(
                  color: AppTheme.lime,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.77,
                  child: Container(
                    height: 138,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3D7034),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: const BoxDecoration(
                        color: AppTheme.lime,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(width: 1.5, color: AppTheme.green),
                          const Positioned(top: 40, child: _Target()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Target extends StatefulWidget {
  const _Target();

  @override
  State<_Target> createState() => _TargetState();
}

class _TargetState extends State<_Target> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _pulse.value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        width: 52 + 6 * _pulse.value,
        height: 52 + 6 * _pulse.value,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.35),
        ),
        alignment: Alignment.center,
        child: child,
      ),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: AppTheme.green,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
