import 'package:flutter/material.dart';

import '../../domain/entities/store_model.dart';
import '../widgets/render_metrics.dart';

class MetricsCard extends StatelessWidget {
  const MetricsCard({super.key, required this.metadata, required this.metrics});

  final StoreModelMetadata metadata;
  final RenderMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rendimiento 3D', style: style.titleSmall),
            const SizedBox(height: 8),
            Text(
              '${metrics.fps.toStringAsFixed(1)} FPS  ·  ${metrics.drawCalls} draw calls',
              style: style.titleMedium,
            ),
            Text(
              '${metrics.triangles} tris visibles / ${metadata.triangles} en el modelo',
            ),
            Text(
              '${(metadata.byteLength / 1000000).toStringAsFixed(2)} MB  ·  Carga 3D: ${metrics.loadMilliseconds} ms',
            ),
            Text(
              '${metadata.productIds.length} productos  ·  ${metadata.routeNodeIds.length} nodos',
            ),
            const SizedBox(height: 8),
            Text(
              'Medición continua mientras este panel está abierto.\nEl emulador no representa el rendimiento de un teléfono.',
              style: style.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
