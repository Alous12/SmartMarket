import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/store_model.dart';
import '../providers/store_model_provider.dart';
import '../widgets/product_sheets.dart';
import '../widgets/render_metrics.dart';
import '../widgets/supermarket_viewport.dart';

/// Cantidad de paradas de la ruta de demostración mientras no exista la lista
/// de compras real.
const _maxRouteStops = 8;

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
  bool _topView = false;
  bool _exitDialogOpen = false;
  bool _changingStore = false;
  int _stopIndex = 0;
  int _collected = 0;

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
      _topView = false;
      _stopIndex = 0;
      _collected = 0;
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

  List<StoreProduct> _routeStops(StoreModel model) =>
      model.metadata.products.take(_maxRouteStops).toList();

  void _advance({required bool collected}) {
    setState(() {
      if (collected) _collected++;
      _stopIndex++;
    });
  }

  void _restartRoute() {
    setState(() {
      _stopIndex = 0;
      _collected = 0;
    });
  }

  void _toggleTopView() {
    setState(() => _topView = !_topView);
    _viewport?.setView(_topView ? 'superior' : 'inicio');
  }

  Future<void> _openMapOptions(StoreModel model) async {
    final action = await showModalBottomSheet<_MapAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void toggle(VoidCallback change) {
            change();
            setSheetState(() {});
          }

          return _MapOptionsSheet(
            store: model.store,
            panWithOneFinger: _panWithOneFinger,
            showNodes: _showNodes,
            showMetrics: _showMetrics,
            onZoomIn: () => _viewport?.zoomBy(1.6),
            onZoomOut: () => _viewport?.zoomBy(0.625),
            onRotateLeft: () => _viewport?.rotateBy(-45),
            onRotateRight: () => _viewport?.rotateBy(45),
            onTopView: () => _viewport?.setView('superior'),
            onAisleView: () => _viewport?.setView('pasillo'),
            onReset: () => _viewport?.resetView(),
            onToggleMode: () => toggle(() {
              setState(() => _panWithOneFinger = !_panWithOneFinger);
              _viewport?.setOneFingerMode(_panWithOneFinger ? 'pan' : 'rotate');
            }),
            onToggleNodes: () => toggle(() {
              setState(() => _showNodes = !_showNodes);
              _viewport?.showNodes(_showNodes);
            }),
            onToggleMetrics: () =>
                toggle(() => setState(() => _showMetrics = !_showMetrics)),
          );
        },
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _SelectStore(:final store):
        await _selectStore(store);
      case _OpenProducts():
        await _openProductList(model);
      case _OpenUsers():
        await context.pushNamed('users');
      case _OpenAssistant():
        await context.pushNamed('assistant');
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(storeModelProvider);
    return PopScope<Object?>(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: model.when(
            loading: () => const _CenteredMessage(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.green),
                  SizedBox(height: 16),
                  Text('Cargando el supermercado…'),
                ],
              ),
            ),
            error: (error, stack) => _CenteredMessage(
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
            data: (model) => _buildNavigation(context, model),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigation(BuildContext context, StoreModel model) {
    final names = ref.watch(productNamesProvider).value ?? const {};
    final stops = _routeStops(model);
    final current = _stopIndex < stops.length ? stops[_stopIndex] : null;
    String nameOf(StoreProduct product) => names[product.id] ?? product.name;

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
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InstructionCard(
                  title: current == null
                      ? 'Dirígete a las cajas'
                      : 'Dirígete a ${_locationOf(current)}',
                  subtitle: current == null
                      ? 'Ya recorriste todas las paradas'
                      : 'Busca ${nameOf(current)}',
                  value: '${stops.length - _stopIndex}',
                  unit: stops.length - _stopIndex == 1 ? 'parada' : 'paradas',
                ),
                const SizedBox(height: 20),
                _MapButton(
                  tooltip: _topView ? 'Ver en 3D' : 'Vista superior',
                  onPressed: _toggleTopView,
                  child: Text(
                    _topView ? '2D' : '3D',
                    style: const TextStyle(
                      color: AppTheme.green,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _MapButton(
                  tooltip: 'Centrar mapa',
                  onPressed: () => _viewport?.resetView(),
                  child: const Icon(Icons.adjust, color: AppTheme.ink),
                ),
                const SizedBox(height: 12),
                _MapButton(
                  tooltip: 'Opciones del mapa',
                  onPressed: () => _openMapOptions(model),
                  child: const Icon(Icons.layers_outlined, color: AppTheme.ink),
                ),
                if (_showMetrics) ...[
                  const SizedBox(height: 12),
                  ValueListenableBuilder<RenderMetrics>(
                    valueListenable: _metrics,
                    builder: (context, metrics, child) => _MetricsCard(
                      metadata: model.metadata,
                      metrics: metrics,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _NextStopSheet(
            stops: stops,
            index: _stopIndex,
            collected: _collected,
            nameOf: nameOf,
            onSkip: () => _advance(collected: false),
            onCollected: () => _advance(collected: true),
            onRestart: _restartRoute,
          ),
        ),
      ],
    );
  }
}

String _locationOf(StoreProduct product) =>
    product.category.isEmpty ? 'la siguiente parada' : product.category;

String _initials(String name) {
  final words = name
      .split(RegExp(r'[\s_]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final letters = words.length == 1
      ? words.first.substring(0, words.first.length.clamp(0, 2))
      : '${words[0][0]}${words[1][0]}';
  return letters.toUpperCase();
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.unit,
  });

  final String title;
  final String subtitle;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.lime,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.turn_right, size: 30, color: AppTheme.ink),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF6BB33F),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              Text(
                unit,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _NextStopSheet extends StatelessWidget {
  const _NextStopSheet({
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
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppTheme.ink,
                  ),
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
                _StopProduct(product: current, name: nameOf(current))
              else
                const _StopFinished(),
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

class _StopProduct extends StatelessWidget {
  const _StopProduct({required this.product, required this.name});

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
            color: AppTheme.tint,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            _initials(name),
            style: const TextStyle(
              color: AppTheme.green,
              fontSize: 22,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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

class _StopFinished extends StatelessWidget {
  const _StopFinished();

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

sealed class _MapAction {
  const _MapAction();
}

class _SelectStore extends _MapAction {
  const _SelectStore(this.store);

  final Supermarket store;
}

class _OpenProducts extends _MapAction {
  const _OpenProducts();
}

class _OpenUsers extends _MapAction {
  const _OpenUsers();
}

class _OpenAssistant extends _MapAction {
  const _OpenAssistant();
}

/// Herramientas del mapa que no aparecen en el diseño principal: cambio de
/// supermercado, cámara, nodos, rendimiento y accesos administrativos.
class _MapOptionsSheet extends StatelessWidget {
  const _MapOptionsSheet({
    required this.store,
    required this.panWithOneFinger,
    required this.showNodes,
    required this.showMetrics,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onTopView,
    required this.onAisleView,
    required this.onReset,
    required this.onToggleMode,
    required this.onToggleNodes,
    required this.onToggleMetrics,
  });

  final Supermarket store;
  final bool panWithOneFinger;
  final bool showNodes;
  final bool showMetrics;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onTopView;
  final VoidCallback onAisleView;
  final VoidCallback onReset;
  final VoidCallback onToggleMode;
  final VoidCallback onToggleNodes;
  final VoidCallback onToggleMetrics;

  @override
  Widget build(BuildContext context) {
    const sectionStyle = TextStyle(
      color: AppTheme.ink,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Supermercado', style: sectionStyle),
            const SizedBox(height: 10),
            SegmentedButton<Supermarket>(
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
                  Navigator.pop(context, _SelectStore(selection.single)),
            ),
            const SizedBox(height: 20),
            const Text('Cámara', style: sectionStyle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ToolButton(Icons.add, 'Acercar', onZoomIn),
                _ToolButton(Icons.remove, 'Alejar', onZoomOut),
                _ToolButton(Icons.rotate_left, 'Girar a la izquierda', onRotateLeft),
                _ToolButton(Icons.rotate_right, 'Girar a la derecha', onRotateRight),
                _ToolButton(Icons.map_outlined, 'Vista superior', onTopView),
                _ToolButton(Icons.directions_walk, 'Vista de pasillo', onAisleView),
                _ToolButton(Icons.center_focus_strong, 'Centrar mapa', onReset),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Un dedo desplaza el mapa'),
              subtitle: const Text('Si está apagado, un dedo gira la cámara'),
              value: panWithOneFinger,
              onChanged: (_) => onToggleMode(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar nodos de ruta'),
              value: showNodes,
              onChanged: (_) => onToggleNodes(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rendimiento 3D'),
              value: showMetrics,
              onChanged: (_) => onToggleMetrics(),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Productos del mapa'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, const _OpenProducts()),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Asistente SmartMarket'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, const _OpenAssistant()),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.people_outline),
              title: const Text('Usuarios'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, const _OpenUsers()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton(this.icon, this.tooltip, this.onPressed);

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: AppTheme.ink),
      style: IconButton.styleFrom(
        side: const BorderSide(color: AppTheme.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(48, 48),
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
