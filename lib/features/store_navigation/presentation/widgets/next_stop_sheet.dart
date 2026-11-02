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

class NextStopSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final finished = index >= stops.length;
    final current = finished ? null : stops[index];
    final progress = stops.isEmpty ? 0.0 : index / stops.length;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.track,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      finished
                          ? 'Ruta completada'
                          : 'Siguiente parada · ${index + 1} de ${stops.length}',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(Icons.schedule, size: 16, color: AppTheme.ink),
                  const SizedBox(width: 4),
                  Text(
                    '$collected de ${stops.length} listos',
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: AppTheme.lime,
                  backgroundColor: AppTheme.track,
                ),
              ),
              const SizedBox(height: 20),
              if (current != null)
                StopProduct(product: current, name: nameOf(current))
              else
                const StopFinished(),
              const SizedBox(height: 20),
              SizedBox(
                height: 60,
                child: finished
                    ? FilledButton.icon(
                        onPressed: onRestart,
                        icon: const Icon(Icons.replay),
                        label: const Text('Repetir ruta'),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              onPressed: onSkip,
                              child: const Text('Saltar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: FilledButton.icon(
                              onPressed: onCollected,
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
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.lime,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            _initials(name),
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
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
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (product.category.isNotEmpty) product.category,
                  product.id,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.tint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '1 unidad',
                  style: TextStyle(
                    color: AppTheme.green,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.lime,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.check, size: 34, color: AppTheme.ink),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Listo! Tienes todo',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Dirígete a la caja para pagar.',
                style: TextStyle(color: AppTheme.muted, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
