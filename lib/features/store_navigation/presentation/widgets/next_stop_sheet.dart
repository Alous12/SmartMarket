import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/store_model.dart';

String _initials(String name) {
  final words = name
      .split(RegExp(r'[\s_]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final letters = words.length == 1
      ? words.first.substring(0, words.first.length.clamp(0, 2).toInt())
      : '${words[0][0]}${words[1][0]}';
  return letters.toUpperCase();
}

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

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    final index = widget.index;
    final finished = index >= stops.length;
    final current = finished ? null : stops[index];
    final progress = stops.isEmpty ? 0.0 : index / stops.length;
    final header = finished
        ? 'Ruta completada'
        : _folded
        ? '${widget.nameOf(current!)} · ${index + 1} de ${stops.length}'
        : 'Siguiente parada · ${index + 1} de ${stops.length}';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.track,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      header,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _folded && !finished
                            ? AppTheme.ink
                            : AppTheme.muted,
                        fontSize: 14,
                        fontWeight: _folded && !finished
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  const Icon(Icons.schedule, size: 15, color: AppTheme.ink),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.collected} de ${stops.length} listos',
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (!_folded) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    color: AppTheme.lime,
                    backgroundColor: AppTheme.track,
                  ),
                ),
                const SizedBox(height: 12),
                if (current != null)
                  StopProduct(product: current, name: widget.nameOf(current))
                else
                  const StopFinished(),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: finished
                    ? FilledButton.icon(
                        onPressed: widget.onRestart,
                        icon: const Icon(Icons.replay),
                        label: const Text('Repetir ruta'),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              onPressed: widget.onSkip,
                              child: const Text('Saltar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: FilledButton.icon(
                              onPressed: widget.onCollected,
                              icon: const Icon(Icons.check),
                              label: const Text('Ya lo tengo'),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StopProduct extends StatelessWidget {
  const StopProduct({super.key, required this.product, required this.name});

  final StoreProduct product;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.lime,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _initials(name),
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                [
                  if (product.category.isNotEmpty) product.category,
                  product.id,
                  '1 unidad',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, fontSize: 14),
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
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.lime,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.check, size: 26, color: AppTheme.ink),
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
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Ya recogiste todos tus productos.',
                style: TextStyle(color: AppTheme.muted, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
