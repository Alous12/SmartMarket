import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/format/location.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../assistant/presentation/widgets/product_choice_sheet.dart';
import '../../domain/entities/store_model.dart';

/// Hoja con la parada actual. Es compacta para dejar ver el mapa y, al tocar la
/// barrita de arriba, se pliega a una sola línea con los botones.
class NextStopSheet extends StatefulWidget {
  const NextStopSheet({
    super.key,
    required this.stops,
    required this.index,
    required this.collected,
    required this.nameOf,
    required this.onSkip,
    required this.onCollected,
    required this.onRestart,
  });

  final List<StoreProduct> stops;
  final int index;
  final int collected;
  final String Function(StoreProduct product) nameOf;
  final VoidCallback onSkip;
  final VoidCallback onCollected;
  final VoidCallback onRestart;

  @override
  State<NextStopSheet> createState() => _NextStopSheetState();
}

class _NextStopSheetState extends State<NextStopSheet> {
  bool _folded = false;

  void _toggle() => setState(() => _folded = !_folded);

  void _skip() {
    HapticFeedback.selectionClick();
    widget.onSkip();
  }

  void _collect() {
    HapticFeedback.selectionClick();
    widget.onCollected();
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    final index = widget.index;
    final finished = index >= stops.length;
    final current = finished ? null : stops[index];
    final header = finished
        ? 'Ruta completada'
        : _folded
        ? '${widget.nameOf(current!)} · ${index + 1} de ${stops.length}'
        : 'Siguiente parada · ${index + 1} de ${stops.length}';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL + 4),
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                label: _folded ? 'Mostrar la parada' : 'Plegar la parada',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  onVerticalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity > 0 && !_folded) _toggle();
                    if (velocity < 0 && _folded) _toggle();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE1D8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_folded || finished)
                Text(
                  header,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                AnimatedSwitcher(
                  duration: AppTheme.motion(context, AppTheme.slow),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  child: StopProduct(
                    key: ValueKey('stop-$index'),
                    product: current!,
                    name: widget.nameOf(current),
                    header: header,
                  ),
                ),
              if (finished) ...[
                const SizedBox(height: 12),
                const StopFinished(),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 58,
                child: finished
                    ? FilledButton.icon(
                        onPressed: widget.onRestart,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Repetir ruta'),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _skip,
                              child: const Text('Saltar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _PressScale(
                              child: FilledButton.icon(
                                onPressed: _collect,
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('Ya lo tengo'),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              if (!finished) ...[
                const SizedBox(height: 16),
                _StopSegments(total: stops.length, done: index),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Un segmento por parada: verde las recorridas, lima la actual.
class _StopSegments extends StatelessWidget {
  const _StopSegments({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox(height: 8);
    final duration = AppTheme.motion(context, AppTheme.slow);
    return Semantics(
      label: '$done de $total paradas recorridas',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: i < done
                        ? AppTheme.green
                        : i == done
                        ? AppTheme.lime
                        : AppTheme.track,
                  ),
                  duration: duration,
                  builder: (context, color, child) => Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Encoge un poco el botón mientras se presiona.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: AppTheme.motion(context, const Duration(milliseconds: 120)),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Producto de la parada: foto, encabezado, nombre grande y dónde está.
class StopProduct extends StatelessWidget {
  const StopProduct({
    super.key,
    required this.product,
    required this.name,
    this.header,
  });

  final StoreProduct product;
  final String name;
  final String? header;

  @override
  Widget build(BuildContext context) {
    final detail = [
      placeLabel(
        section: product.section,
        shelf: product.shelf,
        fallback: product.category.isEmpty ? product.id : product.category,
      ),
      if (product.price != null) formatBs(product.price!),
    ].join(' · ');
    return Row(
      children: [
        const ProductPhoto(
          size: 72,
          dashed: true,
          color: Color(0xFFFDF1DC),
          iconColor: Color(0xFFB0721E),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header != null)
                Text(
                  header!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StopFinished extends StatelessWidget {
  const StopFinished({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1),
          duration: AppTheme.motion(context, const Duration(milliseconds: 400)),
          curve: Curves.easeOutBack,
          builder: (context, value, child) =>
              Transform.scale(scale: value, child: child),
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppTheme.lime,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 28,
              color: AppTheme.ink,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Listo! Tienes todo',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Ya recogiste todos tus productos.',
                style: TextStyle(color: AppTheme.muted, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
