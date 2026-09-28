import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/store_model.dart';
import '../providers/store_model_provider.dart';
import '../widgets/render_metrics.dart';
import '../widgets/supermarket_viewport.dart';

class SupermarketScreen extends ConsumerStatefulWidget {
  const SupermarketScreen({super.key});

  @override
  ConsumerState<SupermarketScreen> createState() => _SupermarketScreenState();
}

class _SupermarketScreenState extends ConsumerState<SupermarketScreen> {
  GlobalKey<SupermarketViewportState> _viewportKey = GlobalKey();
  final _metrics = ValueNotifier(const RenderMetrics());
  bool _showMetrics = false;

  @override
  void dispose() {
    _metrics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(storeModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SmartMarket',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              'Mi supermercado',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Rendimiento',
            isSelected: _showMetrics,
            selectedIcon: const Icon(Icons.speed),
            icon: const Icon(Icons.speed_outlined),
            onPressed: () => setState(() => _showMetrics = !_showMetrics),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: model.when(
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Cargando el supermercado…'),
              ],
            ),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudo cargar el modelo del supermercado.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(storeModelProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
          data: (model) => Stack(
            fit: StackFit.expand,
            children: [
              SupermarketViewport(
                key: _viewportKey,
                model: model,
                metrics: _metrics,
                measureContinuously: _showMetrics,
                onRetry: () => setState(() => _viewportKey = GlobalKey()),
              ),
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Arrastra para explorar\nPellizca para acercarte',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: _showMetrics ? 250 : 24,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      IconButton(
                        tooltip: 'Acercar',
                        onPressed: () =>
                            _viewportKey.currentState?.zoomBy(1.25),
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        tooltip: 'Alejar',
                        onPressed: () => _viewportKey.currentState?.zoomBy(0.8),
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        tooltip: 'Centrar mapa',
                        onPressed: () => _viewportKey.currentState?.resetView(),
                        icon: const Icon(Icons.center_focus_strong),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showMetrics)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: ValueListenableBuilder<RenderMetrics>(
                    valueListenable: _metrics,
                    builder: (context, metrics, child) => _MetricsCard(
                      metadata: model.metadata,
                      metrics: metrics,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.metadata, required this.metrics});

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
