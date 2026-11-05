import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../assistant/domain/entities/recipe_availability.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/store_model.dart';
import '../../domain/services/store_route_planner.dart';
import '../controllers/store_edit_controller.dart';
import '../providers/store_model_provider.dart';
import '../widgets/bottom_action.dart';
import '../widgets/edit_banner.dart';
import '../widgets/map_options_sheet.dart';
import '../widgets/map_widgets.dart';
import '../widgets/metrics_card.dart';
import '../widgets/next_stop_sheet.dart';
import '../widgets/product_sheets.dart';
import '../widgets/render_metrics.dart';
import '../widgets/route_picker_sheet.dart';
import '../widgets/route_summary_card.dart';
import '../widgets/store_segments.dart';
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
  bool _topView = false;
  bool _exitDialogOpen = false;
  bool _changingStore = false;
  late final StoreEditController _edit;
  SupermarketViewportState? get _viewport => _viewportKey.currentState;

  @override
  void initState() {
    super.initState();
    _edit = StoreEditController(
      ref: ref,
      viewport: () => _viewport,
      onAisleView: _showAisleView,
    )..addListener(() => setState(() {}));
  }

  Future<void> _confirmExit() async {
    if (_exitDialogOpen) return;
    _exitDialogOpen = true;
    final exit = await confirmExit(context);
    _exitDialogOpen = false;
    if (exit && mounted) {
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
    _edit.dispose();
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
      ref.read(navigationSessionProvider.notifier).clear();
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

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

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

  void _advanceNavigation({required bool collected}) {
    ref.read(navigationSessionProvider.notifier).advance(collected: collected);
  }

  StoreRoutePlan _planRoute(StoreModel model, List<String> productIds) {
    final startNode = startNodeOf(model);
    return const StoreRoutePlanner().plan(
      routeNodes: model.metadata.routeNodes,
      products: model.metadata.products,
      startNodeId: startNode,
      productIds: productIds,
    );
  }

  /// Ruta con los productos que elige el usuario; sin selección se quita la ruta.
  Future<void> _pickRoute(StoreModel model) async {
    final session = ref.read(navigationSessionProvider);
    final chosen = await showRoutePicker(
      context,
      products: model.metadata.products,
      selected: [for (final p in session.stops) p.id],
    );
    if (!mounted || chosen == null) return;
    if (chosen.isEmpty) {
      _clearRoute();
      return;
    }
    try {
      final plan = _planRoute(model, chosen);
      ref.read(navigationSessionProvider.notifier).start(plan);
      _showTopView();
    } on StateError catch (error) {
      _toast(error.message);
    }
  }

  /// Ruta armada por el asistente: abre el supermercado que tiene los
  /// ingredientes y traza el recorrido por sus productos.
  Future<void> _showShoppingRoute(ShoppingRoute route) async {
    final store = Supermarket.values
        .where((store) => store.assetPath == route.modelUrl)
        .firstOrNull;
    if (store == null) {
      _toast('No se encontró el mapa de ${route.branchName}.');
      return;
    }
    await _selectStore(store);
    if (!mounted) return;
    final StoreModel model;
    try {
      model = await ref.read(storeModelProvider.future);
    } on Object {
      if (mounted) _toast('No se pudo cargar el mapa de ${route.branchName}.');
      return;
    }
    if (!mounted) return;
    if (model.store != store) {
      _toast('Tu cuenta solo puede ver ${model.store.title}.');
      return;
    }
    final productIds = storeProductIdsFor(route, model.metadata.products);
    if (productIds.isEmpty) {
      _toast('Los productos de la ruta no aparecen en el mapa.');
      return;
    }
    try {
      ref
          .read(navigationSessionProvider.notifier)
          .start(_planRoute(model, productIds));
      _showTopView();
    } on StateError catch (error) {
      _toast(error.message);
      return;
    }
    if (route.missing.isNotEmpty) {
      _toast('No hay en ${route.branchName}: ${route.missing.join(', ')}.');
    }
  }

  void _showTopView() {
    setState(() => _topView = true);
    _viewport?.setView('superior');
  }

  void _showAisleView() {
    setState(() => _topView = false);
    _viewport?.setView('pasillo');
  }

  void _toggleTopView() {
    if (_topView) {
      _showAisleView();
    } else {
      _showTopView();
    }
  }

  Future<void> _openMapOptions(StoreModel model) async {
    final action = await showModalBottomSheet<MapAction>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MapOptionsSheet(
        isAdmin:
            ref.read(authControllerProvider).asData?.value?.isAdmin ?? false,
        storeLocked: ref.read(lockedStoreProvider) != null,
        editing: _edit.editing,
        store: model.store,
        panWithOneFinger: _panWithOneFinger,
        showNodes: _showNodes,
        showMetrics: _showMetrics,
        onZoomIn: () => _viewport?.zoomBy(1.2),
        onZoomOut: () => _viewport?.zoomBy(1 / 1.2),
        onRotateLeft: () => _viewport?.rotateBy(-45),
        onRotateRight: () => _viewport?.rotateBy(45),
        onTopView: _showTopView,
        onAisleView: _showAisleView,
        onReset: () => _viewport?.resetView(),
        onToggleMode: () {
          setState(() => _panWithOneFinger = !_panWithOneFinger);
          _viewport?.setOneFingerMode(_panWithOneFinger ? 'pan' : 'rotate');
        },
        onToggleNodes: () {
          setState(() => _showNodes = !_showNodes);
          _viewport?.showNodes(_showNodes);
        },
        onToggleMetrics: () => setState(() => _showMetrics = !_showMetrics),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case SelectStoreAction(:final store):
        await _selectStore(store);
        break;
      case OpenProductsAction():
        await _openProductList(model);
        break;
      case PickRouteAction():
        await _pickRoute(model);
        break;
      case OpenUsersAction():
        await context.pushNamed('users');
        break;
      case ToggleEditAction():
        _edit.toggle(model);
        break;
      case OpenAssistantAction():
        final route = await context.pushNamed<ShoppingRoute>('assistant');
        if (mounted && route != null) await _showShoppingRoute(route);
        break;
    }
  }

  void _clearRoute() => ref.read(navigationSessionProvider.notifier).clear();

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(selectedStoreProvider);
    final model = ref.watch(storeModelProvider);
    // La ruta del asistente se inicia mientras carga otro supermercado: sin este
    // watch la sesión se destruiría antes de que el mapa la muestre.
    ref.watch(navigationSessionProvider);
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
          bottom: ref.watch(lockedStoreProvider) != null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: StoreSegments(
                        store: store,
                        onChanged: _selectStore,
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
                  CircularProgressIndicator(color: AppTheme.green),
                  SizedBox(height: 16),
                  Text('Cargando el supermercado…'),
                ],
              ),
            ),
            error: (error, stack) => CenteredMessage(
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
    final viewerNames = {
      for (final product in model.metadata.products) product.id: product.name,
      ...names,
    };
    final session = ref.watch(navigationSessionProvider);
    final stops = session.stops;
    final current = session.current;
    String nameOf(StoreProduct product) => names[product.id] ?? product.name;
    final routePlan = session.plan;
    final isAdmin =
        ref.watch(authControllerProvider).asData?.value?.isAdmin ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        SupermarketViewport(
          key: _viewportKey,
          model: model,
          metrics: _metrics,
          measureContinuously: _showMetrics,
          productNames: viewerNames,
          onProductTapped: (id) => _edit.editing
              ? _edit.onSlotTapped(model, id)
              : _editProduct(model, id),
          onRetry: _retryViewer,
          routePlan: session.plan,
          completedStops: session.nextProductIndex,
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isAdmin) ...[
                  InstructionCard(
                    title: routePlan == null
                        ? 'Arma tu ruta'
                        : current == null
                        ? 'Dirígete a las cajas'
                        : 'Dirígete a ${locationOf(current)}',
                    subtitle: routePlan == null
                        ? 'Elige los productos que buscas'
                        : current == null
                        ? 'Ya recorriste todas las paradas'
                        : 'Busca ${nameOf(current)}',
                    value: '${session.pending}',
                    unit: session.pending == 1 ? 'parada' : 'paradas',
                  ),
                  const SizedBox(height: 20),
                ],
                MapButton(
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
                MapButton(
                  tooltip: 'Centrar mapa',
                  onPressed: () => _viewport?.resetView(),
                  child: const Icon(Icons.adjust, color: AppTheme.ink),
                ),
                const SizedBox(height: 12),
                MapButton(
                  tooltip: 'Opciones del mapa',
                  onPressed: () => _openMapOptions(model),
                  child: const Icon(Icons.layers_outlined, color: AppTheme.ink),
                ),
                if (_showMetrics) ...[
                  const SizedBox(height: 12),
                  ValueListenableBuilder<RenderMetrics>(
                    valueListenable: _metrics,
                    builder: (context, metrics, child) =>
                        MetricsCard(metadata: model.metadata, metrics: metrics),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_edit.editing)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: EditBanner(
              carrying: _edit.carrying,
              busy: _edit.busy,
              onDropCarry: _edit.dropCarry,
              onFinish: () => _edit.toggle(model),
            ),
          )
        else if (isAdmin)
          BottomAction(
            onPressed: () => _edit.toggle(model),
            icon: Icons.edit_location_alt_outlined,
            label: 'Editar tienda',
          )
        else if (routePlan == null)
          BottomAction(
            onPressed: () => _pickRoute(model),
            icon: Icons.add_road,
            label: 'Armar mi ruta',
          )
        else
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NextStopSheet(
              stops: stops,
              index: session.nextProductIndex,
              collected: session.collected,
              nameOf: nameOf,
              onSkip: () => _advanceNavigation(collected: false),
              onCollected: () => _advanceNavigation(collected: true),
              onRestart: () =>
                  ref.read(navigationSessionProvider.notifier).restart(),
            ),
          ),
        if (routePlan != null && !_edit.editing)
          Positioned(
            bottom: _showMetrics ? 238 : 16,
            left: 16,
            right: 76,
            child: RouteSummaryCard(
              plan: routePlan,
              nameOf: nameOf,
              onClear: _clearRoute,
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
                  MetricsCard(metadata: model.metadata, metrics: metrics),
            ),
          ),
      ],
    );
  }
}
