import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers/store_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_or_error_state.dart';
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
import '../../../../core/widgets/staggered_entrance.dart';
import '../widgets/bottom_action.dart';
import '../widgets/route_complete_view.dart';
import '../widgets/store_labels.dart';
import 'before_walking_screen.dart';
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

  /// False si el usuario eligió ver solo la ruta, sin seguir sus pasos.
  bool _tracking = true;

  /// Ruta que armó el asistente (para el resumen al terminar).
  ShoppingRoute? _activeRoute;
  DateTime? _routeStartedAt;

  /// Productos (id de la BD) ya descontados del stock en la ruta en curso: al
  /// repetirla no se vuelven a descontar.
  final _pickedUp = <int>{};

  /// Algún «Ya lo tengo» cambió el stock: al quitar la ruta se recargan los datos.
  bool _stockChanged = false;

  /// La ruta vino de una receta del asistente (queda en su historial).
  String? get _activeRecipe => _activeRoute == null ? null : 'receta';
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
      onNavigationView: _showTopView,
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
      (previous, walking) => _motion.active = walking && _tracking,
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
      case ShowRouteRequest(:final route, :final tracking):
        _setTracking(tracking);
        await _showShoppingRoute(route);
      case StartEditRequest():
        final StoreModel model;
        try {
          model = await ref.read(storeModelProvider.future);
        } on Object {
          return;
        }
        if (mounted && !_edit.editing) _edit.toggle(model);
      case PlaceProductRequest():
        // Colocar productos del inventario se hace en el plano 2D del admin.
        break;
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
    final product = ref.read(navigationSessionProvider).current;
    ref.read(navigationSessionProvider.notifier).advance(collected: collected);
    if (collected && product != null) _discountStock(product);
  }

  /// «Ya lo tengo»: descuenta una unidad del stock de la sucursal en la base de
  /// datos. No frena la ruta: si falla, solo avisa.
  Future<void> _discountStock(StoreProduct product) async {
    final productId = product.dbId;
    final branchId = ref.read(storeModelProvider).value?.branchId;
    if (productId == null || branchId == null || !_pickedUp.add(productId)) {
      return;
    }
    try {
      await ref
          .read(catalogApiProvider)
          .collectProduct(productId, branchId: branchId);
      _stockChanged = true;
    } on Object {
      _pickedUp.remove(productId);
      if (mounted) {
        _toast('No se pudo descontar "${product.name}" del stock.');
      }
    }
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

  /// Activa o apaga el seguimiento de pasos de la ruta en curso.
  void _setTracking(bool value) {
    _tracking = value;
    _motion.active =
        value && ref.read(navigationSessionProvider).current != null;
  }

  void _restartRoute() {
    _routeStartedAt = DateTime.now();
    ref.read(navigationSessionProvider.notifier).restart();
  }

  void _startNavigation(StoreModel model, StoreRoutePlan plan) {
    _routeStartedAt = DateTime.now();
    _pickedUp.clear();
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

    final insets = (
      edge(_topPanelKey, bottom: false),
      edge(_bottomPanelKey, bottom: true),
    );
    final current = _viewport;
    // Solo se avisa al visor 3D si los márgenes cambiaron: cada aviso es una
    // llamada a JavaScript.
    if (current == null ||
        (identical(current, _insetsViewport) && insets == _lastInsets)) {
      return;
    }
    _insetsViewport = current;
    _lastInsets = insets;
    current.setInsets(insets.$1, insets.$2);
  }

  SupermarketViewportState? _insetsViewport;
  (double, double)? _lastInsets;

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
    // Antes de seguir los pasos, el usuario se para en la entrada.
    final tracking = await BeforeWalkingScreen.open(
      context,
      model.store.displayName,
    );
    if (!mounted || tracking == null) return;
    _activeRoute = null;
    _setTracking(tracking);
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
      _activeRoute = route;
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
      case OpenStaffAction():
        await context.pushNamed('staff');
        break;
      case ToggleEditAction():
        _edit.toggle(model);
        break;
    }
  }

  void _clearRoute() {
    _activeRoute = null;
    _tracking = true;
    _pickedUp.clear();
    ref.read(navigationSessionProvider.notifier).clear();
    // El stock que muestran Productos y el mapa se pone al día al terminar, no
    // durante la ruta: así el mapa no se recarga mientras la persona camina.
    if (_stockChanged) {
      _stockChanged = false;
      ref.invalidate(storeModelProvider);
    }
  }

  /// Lleva a la pestaña Asistente para armar la lista desde un plato.
  void _openAssistant() {
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null) {
      shell.goBranch(0);
    } else {
      context.goNamed('assistant');
    }
  }

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
    final locked = ref.watch(lockedStoreProvider) != null;
    return PopScope<Object?>(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFDDE3D6),
        // El teclado no debe cambiar el tamaño del visor ni el encuadre de la cámara.
        resizeToAvoidBottomInset: false,
        body: model.when(
          loading: () => _Placeholder(
            header: _greeting(store, locked),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  ),
                  child: const CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppTheme.green,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cargando el supermercado…',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          error: (error, stack) => _Placeholder(
            header: _greeting(store, locked),
            child: EmptyOrErrorState(
              icon: Icons.view_in_ar_outlined,
              title: 'No se pudo cargar el modelo del supermercado.',
              message:
                  'Revisa tu conexión o que el servidor esté encendido e inténtalo otra vez.',
              onRetry: () => ref.invalidate(storeModelProvider),
            ),
          ),
          data: (model) => _buildNavigation(context, model),
        ),
      ),
    );
  }

  /// Saludo, cierre de sesión y selector de sucursal (sin ruta en curso).
  Widget _greeting(Supermarket store, bool locked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Abierto desde el plano del admin: se vuelve con este botón.
            if (Navigator.of(context).canPop()) ...[
              MapButton(
                tooltip: 'Volver al plano',
                size: 48,
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  _welcome(ref.watch(authControllerProvider).asData?.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            MapButton(
              tooltip: 'Cerrar sesión',
              size: 48,
              onPressed: _logout,
              child: const Icon(
                Icons.logout_rounded,
                size: 22,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
        if (!locked) ...[
          const SizedBox(height: 12),
          StoreSegments(store: store, onChanged: _selectStore),
        ],
      ],
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
    final locked = ref.watch(lockedStoreProvider) != null;
    final navigating = routePlan != null && !_edit.editing;
    final finished = navigating && session.current == null && stops.isNotEmpty;

    final Widget top;
    if (_edit.editing) {
      top = EditBanner(
        carrying: _edit.carrying,
        busy: _edit.busy,
        onDropCarry: _edit.dropCarry,
        onFinish: () => _edit.toggle(model),
      );
    } else if (navigating) {
      top = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              MapButton(
                tooltip: 'Quitar ruta',
                onPressed: _clearRoute,
                child: const Icon(
                  Icons.close_rounded,
                  size: 26,
                  color: AppTheme.ink,
                ),
              ),
              const Spacer(),
              Flexible(
                flex: 6,
                child: RouteSummaryCard(
                  plan: routePlan,
                  nameOf: nameOf,
                  onClear: _clearRoute,
                  steps: session.steps,
                  collected: session.collected,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InstructionCard(
            navigating: true,
            title: instruction.title,
            subtitle: instruction.subtitle,
            icon: instruction.icon,
          ),
        ],
      );
    } else {
      top = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _greeting(model.store, locked),
          const SizedBox(height: 12),
          if (isAdmin)
            InstructionCard(
              title: 'Panel administrador',
              subtitle: 'Mapa y productos de tu sucursal',
              icon: Icons.storefront_outlined,
              value: '${model.metadata.products.length}',
              unit: model.metadata.products.length == 1
                  ? 'producto'
                  : 'productos',
            )
          else
            InstructionCard(
              title: instruction.title,
              subtitle: instruction.subtitle,
              icon: Icons.route_outlined,
            ),
        ],
      );
    }

    final Widget? bottom;
    if (_edit.editing) {
      bottom = null;
    } else if (navigating && !finished) {
      bottom = NotificationListener<SizeChangedLayoutNotification>(
        // La hoja cambia de alto al plegarse: el mapa se vuelve a centrar.
        onNotification: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _syncInsets());
          return true;
        },
        child: SizeChangedLayoutNotifier(
          child: NextStopSheet(
            key: _bottomPanelKey,
            stops: stops,
            index: session.nextProductIndex,
            collected: session.collected,
            nameOf: nameOf,
            onSkip: () => _advanceNavigation(collected: false),
            onCollected: () => _advanceNavigation(collected: true),
            onRestart: _restartRoute,
          ),
        ),
      );
    } else if (navigating) {
      bottom = null;
    } else {
      bottom = SafeArea(
        top: false,
        child: Padding(
          key: _bottomPanelKey,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isAdmin) ...[
                AssistantHintCard(onTap: _openAssistant),
                const SizedBox(height: 12),
              ],
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: FilledButton.icon(
                  onPressed: isAdmin
                      ? () => _edit.toggle(model)
                      : () => _pickRoute(model),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: Icon(
                    isAdmin
                        ? Icons.edit_location_alt_outlined
                        : Icons.search_rounded,
                    size: 26,
                  ),
                  label: Text(isAdmin ? 'Editar tienda' : 'Armar mi ruta'),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    bottom == null ? 0 : 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        key: _topPanelKey,
                        child: SmSwitcher(
                          size: true,
                          child: KeyedSubtree(
                            key: ValueKey(
                              _edit.editing
                                  ? 'edit'
                                  : navigating
                                  ? 'route'
                                  : 'idle',
                            ),
                            child: top,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Align(
                          alignment: const Alignment(1, -0.35),
                          // En pantallas bajas la columna se achica en vez de cortarse.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topRight,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MapButton(
                                  tooltip: _topView
                                      ? 'Ver en 3D'
                                      : 'Vista superior',
                                  onPressed: _toggleTopView,
                                  child: AnimatedSwitcher(
                                    duration: AppTheme.motion(
                                      context,
                                      AppTheme.fast,
                                    ),
                                    transitionBuilder: (child, animation) =>
                                        ScaleTransition(
                                          scale: animation,
                                          child: child,
                                        ),
                                    child: Text(
                                      _topView ? '2D' : '3D',
                                      key: ValueKey(_topView),
                                      style: const TextStyle(
                                        color: AppTheme.ink,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                MapButton(
                                  tooltip: 'Centrar mapa',
                                  onPressed: () => _viewport?.resetView(),
                                  child: const Icon(
                                    Icons.my_location_rounded,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                MapButton(
                                  tooltip: 'Opciones del mapa',
                                  onPressed: () => _openMapOptions(model),
                                  child: const Icon(
                                    Icons.layers_outlined,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                if (navigating) ...[
                                  const SizedBox(height: 14),
                                  MapButton(
                                    tooltip: 'Alinear con la ruta',
                                    onPressed: _recenter,
                                    child: const Icon(
                                      Icons.explore_outlined,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ?bottom,
          ],
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
        if (finished)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppTheme.motion(context, AppTheme.slow),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - value)),
                  child: child,
                ),
              ),
              child: RouteCompleteView(
                collected: session.collected,
                total: stops.length,
                substitutes:
                    _activeRoute?.stops
                        .where((stop) => stop.isSubstitute)
                        .length ??
                    0,
                minutes: _routeMinutes(),
                estimate: stops.fold<double>(
                  0,
                  (sum, product) => sum + (product.price ?? 0),
                ),
                missing: _activeRoute?.missing ?? const [],
                recipeName: _activeRecipe,
                onRestart: _restartRoute,
                onFinish: _clearRoute,
                onOpenHistory: _activeRecipe == null ? null : _openAssistant,
              ),
            ),
          ),
      ],
    );
  }

  int _routeMinutes() {
    final start = _routeStartedAt;
    if (start == null) return 0;
    final minutes = DateTime.now().difference(start).inSeconds / 60;
    return minutes < 1 ? 1 : minutes.round();
  }
}

/// Estado de carga o error con el saludo y el selector arriba.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: Center(child: child)),
          ],
        ),
      ),
    );
  }
}
