import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/store_model.dart';
import '../providers/store_model_provider.dart';
import '../widgets/product_sheets.dart';
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
  bool _panWithOneFinger = false;
  bool _showNodes = false;
  bool _exitDialogOpen = false;
  bool _changingStore = false;

  SupermarketViewportState? get _viewport => _viewportKey.currentState;

  Future<void> _confirmExit() async {
    if (_exitDialogOpen) return;
    _exitDialogOpen = true;
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    _exitDialogOpen = false;
    if (exit == true && mounted) {
      await _viewport?.shutdown();
      if (mounted) await SystemNavigator.pop();
    }
  }

  Future<void> _logout() async {
    try {
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) context.goNamed('login');
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar la sesión: $error')),
      );
    }
  }

  @override
  void dispose() {
    _metrics.dispose();
    super.dispose();
  }

  Future<void> _selectStore(Supermarket store) async {
    if (_changingStore || store == ref.read(selectedStoreProvider)) return;
    _changingStore = true;
    await _viewport?.shutdown();
    if (!mounted) return;
    ref.read(selectedStoreProvider.notifier).select(store);
    setState(() {
      _changingStore = false;
      _viewportKey = GlobalKey();
      _panWithOneFinger = false;
      _showNodes = false;
    });
  }

  Future<void> _retryViewer() async {
    await _viewport?.shutdown();
    if (mounted) setState(() => _viewportKey = GlobalKey());
  }

  Future<void> _editProduct(StoreModel model, String productId) async {
    final product = model.metadata.products
        .where((p) => p.id == productId)
        .firstOrNull;
    if (product == null) return;
    _viewport?.selectProduct(product.id);
    final names = ref.read(productNamesProvider).value ?? const {};
    final result = await showProductEditor(
      context,
      product: product,
      currentName: names[product.id] ?? product.name,
    );
    if (!mounted) return;
    if (result != null) {
      await ref.read(productNamesProvider.notifier).rename(product, result);
    }
  }

  Future<void> _openProductList(StoreModel model) async {
    final action = await showProductList(
      context,
      store: model.store,
      products: model.metadata.products,
    );
    if (!mounted || action == null) return;
    if (action.edit) {
      await _editProduct(model, action.productId);
    } else {
      _viewport?.selectProduct(action.productId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(selectedStoreProvider);
    final model = ref.watch(storeModelProvider);
    return PopScope<Object?>(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SmartMarket',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                store.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Productos',
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: model.hasValue
                  ? () => _openProductList(model.requireValue)
                  : null,
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
            IconButton(
              tooltip: 'Rendimiento',
              isSelected: _showMetrics,
              selectedIcon: const Icon(Icons.speed),
              icon: const Icon(Icons.speed_outlined),
              onPressed: () => setState(() => _showMetrics = !_showMetrics),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<Supermarket>(
                  showSelectedIcon: false,
                  segments: [
                    for (final option in Supermarket.values)
                      ButtonSegment(
                        value: option,
                        icon: Icon(
                          option == Supermarket.natural
                              ? Icons.storefront_outlined
                              : Icons.store_mall_directory_outlined,
                        ),
                        label: Text(option.shortTitle),
                      ),
                  ],
                  selected: {store},
                  onSelectionChanged: (selection) =>
                      _selectStore(selection.single),
                ),
              ),
            ),
          ),
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
            data: (model) => _buildViewer(context, model),
          ),
        ),
      ),
    );
  }

  Widget _buildViewer(BuildContext context, StoreModel model) {
    final names = ref.watch(productNamesProvider).value ?? const {};
    return Stack(
      fit: StackFit.expand,
      children: [
        SupermarketViewport(
          key: _viewportKey,
          model: model,
          metrics: _metrics,
          measureContinuously: _showMetrics,
          productNames: names,
          onProductTapped: (id) => _editProduct(model, id),
          onRetry: _retryViewer,
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 76,
          child: IgnorePointer(
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _panWithOneFinger
                            ? '1 dedo: mover · 2 dedos: zoom\nToca una caja para renombrarla'
                            : '1 dedo: girar · 2 dedos: mover y zoom\nToca una caja para renombrarla',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: 12,
          bottom: _showMetrics ? 238 : 16,
          child: Align(
            alignment: Alignment.bottomRight,
            child: SingleChildScrollView(
              child: _CameraControls(
                panWithOneFinger: _panWithOneFinger,
                showNodes: _showNodes,
                onZoomIn: () => _viewport?.zoomBy(1.6),
                onZoomOut: () => _viewport?.zoomBy(0.625),
                onRotateLeft: () => _viewport?.rotateBy(-45),
                onRotateRight: () => _viewport?.rotateBy(45),
                onTopView: () => _viewport?.setView('superior'),
                onAisleView: () => _viewport?.setView('pasillo'),
                onReset: () => _viewport?.resetView(),
                onToggleMode: () {
                  setState(() => _panWithOneFinger = !_panWithOneFinger);
                  _viewport?.setOneFingerMode(
                    _panWithOneFinger ? 'pan' : 'rotate',
                  );
                },
                onToggleNodes: () {
                  setState(() => _showNodes = !_showNodes);
                  _viewport?.showNodes(_showNodes);
                },
              ),
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
              builder: (context, metrics, child) =>
                  _MetricsCard(metadata: model.metadata, metrics: metrics),
            ),
          ),
      ],
    );
  }
}

class _CameraControls extends StatelessWidget {
  const _CameraControls({
    required this.panWithOneFinger,
    required this.showNodes,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onTopView,
    required this.onAisleView,
    required this.onReset,
    required this.onToggleMode,
    required this.onToggleNodes,
  });

  final bool panWithOneFinger;
  final bool showNodes;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onTopView;
  final VoidCallback onAisleView;
  final VoidCallback onReset;
  final VoidCallback onToggleMode;
  final VoidCallback onToggleNodes;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: panWithOneFinger
                  ? 'Un dedo desplaza (tocar para girar)'
                  : 'Un dedo gira (tocar para desplazar)',
              isSelected: panWithOneFinger,
              icon: const Icon(Icons.threed_rotation),
              selectedIcon: const Icon(Icons.pan_tool_outlined),
              onPressed: onToggleMode,
            ),
            IconButton(
              tooltip: 'Acercar',
              onPressed: onZoomIn,
              icon: const Icon(Icons.add),
            ),
            IconButton(
              tooltip: 'Alejar',
              onPressed: onZoomOut,
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              tooltip: 'Girar a la izquierda',
              onPressed: onRotateLeft,
              icon: const Icon(Icons.rotate_left),
            ),
            IconButton(
              tooltip: 'Girar a la derecha',
              onPressed: onRotateRight,
              icon: const Icon(Icons.rotate_right),
            ),
            IconButton(
              tooltip: 'Vista superior',
              onPressed: onTopView,
              icon: const Icon(Icons.map_outlined),
            ),
            IconButton(
              tooltip: 'Vista a la altura del pasillo',
              onPressed: onAisleView,
              icon: const Icon(Icons.directions_walk),
            ),
            IconButton(
              tooltip: 'Mostrar nodos de ruta',
              isSelected: showNodes,
              icon: const Icon(Icons.hub_outlined),
              selectedIcon: const Icon(Icons.hub),
              onPressed: onToggleNodes,
            ),
            IconButton(
              tooltip: 'Centrar mapa',
              onPressed: onReset,
              icon: const Icon(Icons.center_focus_strong),
            ),
          ],
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
