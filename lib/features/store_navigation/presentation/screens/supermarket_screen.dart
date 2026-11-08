import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../assistant/domain/entities/recipe_availability.dart';
import '../../../auth/data/auth_api.dart' show AuthSession;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/motion_sensors.dart';
import '../../domain/entities/store_model.dart';
import '../../domain/services/route_guidance.dart';
import '../../domain/services/store_route_planner.dart';
import '../controllers/route_motion_controller.dart';
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
import '../widgets/route_instruction.dart';
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
  late final RouteMotionController _motion;
  StoreRoutePlan? _guidancePlan;
  RouteGuidance? _guidance;
  final _topPanelKey = GlobalKey();
  final _bottomPanelKey = GlobalKey();
  SupermarketViewportState? get _viewport => _viewportKey.currentState;

  @override
  void initState() {
    super.initState();
    _edit = StoreEditController(
      ref: ref,
      viewport: () => _viewport,
      onAisleView: _showAisleView,
    )..addListener(() => setState(() {}));
    _motion = RouteMotionController(
      sensors: ref.read(motionSensorsProvider),
      onSteps: (steps, yaw) => ref
          .read(navigationSessionProvider.notifier)
          .registerSteps(steps, yaw),
      onYaw: (yaw) {
        final pose = ref
            .read(navigationSessionProvider.notifier)
            .updateYaw(yaw);
        if (pose != null) _viewport?.setWalkerPose(pose);
      },
      onUnavailable: () {
        if (mounted) {
          _toast('Este teléfono no detecta pasos: avanza con "Ya lo tengo".');
        }
      },
    );
    // Los sensores solo corren mientras queda una parada por recorrer.
    ref.listenManual(
      navigationSessionProvider.select((session) => session.current != null),
      (previous, walking) => _motion.active = walking,
      fireImmediately: true,
    );
    ref.listenManual(mapRequestProvider, (previous, request) {
      // Se atiende fuera del build: la petición puede llegar antes del primero.
      if (request != null) Future.microtask(() => _handleMapRequest(request));
    }, fireImmediately: true);
  }

  Future<void> _handleMapRequest(MapRequest request) async {
    if (!mounted) return;
    ref.read(mapRequestProvider.notifier).clear();
    switch (request) {
      case SelectStoreRequest(:final store):
        await _selectStore(store);
      case FocusProductRequest(:final productId):
        _viewport?.selectProduct(productId);
      case ShowRouteRequest(:final route):
        await _showShoppingRoute(route);
    }
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
    _motion.dispose();
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
      _topView = false;
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

  /// Aviso breve. Con la hoja de la parada abierta flota sobre ella para no
  /// tapar "Saltar" ni "Ya lo tengo".
  void _toast(String message) {
    // Se espera al próximo cuadro: la hoja puede estar apareciendo recién.
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) _showToast(message);
    });
  }

  void _showToast(String message) {
    final panel = _bottomPanelKey.currentContext?.findRenderObject();
    final above = panel is RenderBox && panel.hasSize ? panel.size.height : 0.0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: above > 0 ? SnackBarBehavior.floating : null,
        margin: above > 0 ? EdgeInsets.fromLTRB(16, 0, 16, above + 8) : null,
      ),
    );
  }

  void _advanceNavigation({required bool collected}) {
    ref.read(navigationSessionProvider.notifier).advance(collected: collected);
  }

  /// Ruta desde la entrada que termina en el último producto.
  StoreRoutePlan _planRoute(StoreModel model, List<String> productIds) {
    return const StoreRoutePlanner().plan(
      routeNodes: model.metadata.routeNodes,
      products: model.metadata.products,
      startNodeId: startNodeOf(model),
      productIds: productIds,
      floorPlan: model.metadata.floorPlan,
    );
  }

  void _startNavigation(StoreModel model, StoreRoutePlan plan) {
    ref
        .read(navigationSessionProvider.notifier)
        .start(plan, northDegrees: model.store.mapNorthDegrees);
  }

  /// Le dice al visor cuánto tapan las tarjetas, para que centre el mapa (y al
  /// muñeco) en la parte que se ve.
  void _syncInsets() {
    if (!mounted) return;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final origin = viewport.localToGlobal(Offset.zero).dy;
    double edge(GlobalKey key, {required bool bottom}) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return 0;
      final top = box.localToGlobal(Offset.zero).dy - origin;
      return bottom
          ? (viewport.size.height - top).clamp(0, viewport.size.height)
          : (top + box.size.height).clamp(0, viewport.size.height);
    }

    _viewport?.setInsets(
      edge(_topPanelKey, bottom: false),
      edge(_bottomPanelKey, bottom: true),
    );
  }

  RouteGuidance? _guidanceFor(StoreRoutePlan? plan) {
    if (plan == null) return null;
    if (!identical(plan, _guidancePlan)) {
      _guidancePlan = plan;
      _guidance = RouteGuidance(plan.path);
    }
    return _guidance;
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
      _startNavigation(model, _planRoute(model, chosen));
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
    final locked = ref.read(lockedStoreProvider);
    if (locked != null && locked != store) {
      _toast('Tu cuenta solo puede ver ${locked.title}.');
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
      _toast('No se pudo abrir el mapa de ${route.branchName}.');
      return;
    }
    final productIds = storeProductIdsFor(route, model.metadata.products);
    if (productIds.isEmpty) {
      _toast('Los productos de la ruta no aparecen en el mapa.');
      return;
    }
    try {
      _startNavigation(model, _planRoute(model, productIds));
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
      case PickRouteAction():
        await _pickRoute(model);
        break;
      case OpenUsersAction():
        await context.pushNamed('users');
        break;
      case ToggleEditAction():
        _edit.toggle(model);
        break;
    }
  }

  void _clearRoute() => ref.read(navigationSessionProvider.notifier).clear();

  void _recenter() {
    ref.read(navigationSessionProvider.notifier).recenter();
    _toast('Listo: ahora miras hacia donde sigue la ruta.');
  }

  /// Saludo con el nombre (sin apellido) de quien inició sesión.
  static String _welcome(AuthSession? session) {
    final name = session?.username.trim() ?? '';
    return name.isEmpty ? 'Bienvenido' : 'Bienvenido, $name';
  }

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
        // El teclado no debe cambiar el tamaño del visor ni el encuadre de la cámara.
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SmartMarket',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                _welcome(ref.watch(authControllerProvider).asData?.value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncInsets());
    final names = ref.watch(productNamesProvider).value ?? const {};
    final viewerNames = {
      for (final product in model.metadata.products) product.id: product.name,
      ...names,
    };
    final session = ref.watch(navigationSessionProvider);
    final stops = session.stops;
    String nameOf(StoreProduct product) => names[product.id] ?? product.name;
    final routePlan = session.plan;
    final instruction = routeInstruction(
      session: session,
      guidance: _guidanceFor(routePlan),
      nameOf: nameOf,
    );
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
          walkerPose: session.pose,
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
                    key: _topPanelKey,
                    title: instruction.title,
                    subtitle: instruction.subtitle,
                    icon: instruction.icon,
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
        else if (routePlan != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            // La hoja cambia de alto al plegarse: el mapa se vuelve a centrar.
            child: NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (_) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _syncInsets(),
                );
                return true;
              },
              child: SizeChangedLayoutNotifier(
                child: Column(
                  key: _bottomPanelKey,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sobre la hoja: encima de ella taparía "Saltar" y "Ya lo tengo".
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
                      child: Row(
                        children: [
                          MapButton(
                            tooltip: 'Alinear con la ruta',
                            onPressed: _recenter,
                            child: const Icon(
                              Icons.explore_outlined,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RouteSummaryCard(
                              plan: routePlan,
                              nameOf: nameOf,
                              onClear: _clearRoute,
                              steps: session.steps,
                            ),
                          ),
                        ],
                      ),
                    ),
                    NextStopSheet(
                      stops: stops,
                      index: session.nextProductIndex,
                      collected: session.collected,
                      nameOf: nameOf,
                      onSkip: () => _advanceNavigation(collected: false),
                      onCollected: () => _advanceNavigation(collected: true),
                      onRestart: () => ref
                          .read(navigationSessionProvider.notifier)
                          .restart(),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (isAdmin)
          BottomAction(
            onPressed: () => _edit.toggle(model),
            icon: Icons.edit_location_alt_outlined,
            label: 'Editar tienda',
          )
        else
          BottomAction(
            onPressed: () => _pickRoute(model),
            icon: Icons.add_road,
            label: 'Armar mi ruta',
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
