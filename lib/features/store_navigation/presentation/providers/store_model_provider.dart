import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/store_providers.dart';
import '../../../assistant/domain/entities/recipe_availability.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/catalog_api.dart';
import '../../domain/entities/store_model.dart';
import '../../domain/services/pedestrian_tracker.dart';
import '../../domain/services/store_route_planner.dart';
import '../../domain/services/yaw_tracker.dart';

/// Sucursal fija del admin (null para usuarios, que pueden elegir).
final lockedStoreProvider = Provider<Supermarket?>((ref) {
  final session = ref.watch(authControllerProvider).asData?.value;
  if (session == null || !session.isAdmin) return null;
  return Supermarket.values
      .where((store) => store.assetPath == session.modelUrl)
      .firstOrNull;
});

/// Supermercado elegido con los botones de la pantalla.
final selectedStoreProvider =
    NotifierProvider<SelectedStoreNotifier, Supermarket>(
      SelectedStoreNotifier.new,
    );

class SelectedStoreNotifier extends Notifier<Supermarket> {
  @override
  Supermarket build() => ref.watch(lockedStoreProvider) ?? Supermarket.natural;

  void select(Supermarket store) =>
      state = ref.read(lockedStoreProvider) ?? store;
}

/// Lo que otra pestaña le pide al mapa, que es quien controla el visor 3D.
sealed class MapRequest {
  const MapRequest();
}

class SelectStoreRequest extends MapRequest {
  const SelectStoreRequest(this.store);

  final Supermarket store;
}

class FocusProductRequest extends MapRequest {
  const FocusProductRequest(this.productId);

  final String productId;
}

class ShowRouteRequest extends MapRequest {
  const ShowRouteRequest(this.route);

  final ShoppingRoute route;
}

final mapRequestProvider = NotifierProvider<MapRequestNotifier, MapRequest?>(
  MapRequestNotifier.new,
);

class MapRequestNotifier extends Notifier<MapRequest?> {
  @override
  MapRequest? build() => null;

  void send(MapRequest request) => state = request;

  void clear() => state = null;
}

/// Modelo 3D con los datos de producto (nombre, categoría, precio y stock)
/// de la base de datos. Si el backend no responde, se usan los del modelo.
final storeModelProvider = FutureProvider.autoDispose<StoreModel>((ref) async {
  final store = ref.watch(selectedStoreProvider);
  final model = await ref.watch(storeModelRepositoryProvider).load(store);
  final CatalogSnapshot catalog;
  try {
    catalog = await ref.watch(catalogApiProvider).loadSnapshot(store.assetPath);
  } on Object {
    return model;
  }
  final products = <StoreProduct>[];
  final empty = <StoreProduct>[];
  for (final product in model.metadata.products) {
    // Sin espacios cargados en la BD se empareja por sku, como antes.
    final data = catalog.slots.isEmpty
        ? catalog.bySku[product.id]
        : switch (catalog.slots[product.slotId]) {
            final id? => catalog.byId[id],
            null => null,
          };
    if (data == null) {
      if (catalog.slots.containsKey(product.slotId)) empty.add(product);
      continue;
    }
    products.add(
      product.copyWith(
        name: data.name,
        category: data.category,
        price: data.price,
        stock: data.stock,
        dbId: data.productId,
      ),
    );
  }
  return StoreModel(
    store: model.store,
    bytes: model.bytes,
    metadata: model.metadata.withProducts(products),
    fromCatalog: true,
    emptySlots: empty,
  );
}, retry: (count, error) => null);

/// Nombres editados del supermercado elegido (product_id -> nombre).
final productNamesProvider =
    AsyncNotifierProvider.autoDispose<
      ProductNamesNotifier,
      Map<String, String>
    >(ProductNamesNotifier.new);

class ProductNamesNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() => ref
      .watch(productNamesRepositoryProvider)
      .load(ref.watch(selectedStoreProvider));

  /// Cambia el nombre visible. Un nombre vacío o igual al original borra el cambio.
  Future<void> rename(StoreProduct product, String name) async {
    final store = ref.read(selectedStoreProvider);
    final current = Map<String, String>.of(state.value ?? const {});
    final clean = name.trim();
    if (clean.isEmpty || clean == product.name) {
      current.remove(product.id);
    } else {
      current[product.id] = clean;
    }
    state = AsyncData(current);
    await ref.read(productNamesRepositoryProvider).save(store, current);
  }

  Future<void> resetAll() async {
    final store = ref.read(selectedStoreProvider);
    state = const AsyncData({});
    await ref.read(productNamesRepositoryProvider).save(store, const {});
  }
}

/// Fuente única de verdad para la ruta activa y su avance.
final navigationSessionProvider =
    NotifierProvider.autoDispose<NavigationSessionNotifier, NavigationSession>(
      NavigationSessionNotifier.new,
    );

class NavigationSession {
  const NavigationSession({
    this.plan,
    this.nextProductIndex = 0,
    this.collected = 0,
    this.pose,
    this.steps = 0,
  });

  final StoreRoutePlan? plan;
  final int nextProductIndex;
  final int collected;

  /// Dónde está el muñeco y cuánto de la ruta se ha recorrido.
  final WalkerPose? pose;

  /// Pasos detectados desde que empezó la ruta.
  final int steps;

  List<StoreProduct> get stops => plan?.products ?? const [];
  StoreProduct? get current =>
      nextProductIndex < stops.length ? stops[nextProductIndex] : null;
  int get pending => stops.length - nextProductIndex;
}

class NavigationSessionNotifier extends Notifier<NavigationSession> {
  PedestrianTracker? _tracker;
  YawReading? _yaw;
  double _northDegrees = 0;

  @override
  NavigationSession build() => const NavigationSession();

  void start(StoreRoutePlan plan, {double northDegrees = 0}) {
    final tracker = PedestrianTracker(
      route: plan.path,
      walkable: plan.walkable,
      northDegrees: northDegrees,
    );
    _tracker = tracker;
    _northDegrees = northDegrees;
    // Si la persona no se mueve no llega otra lectura: se usa la última conocida.
    _applyYaw(_yaw);
    state = NavigationSession(plan: plan, pose: tracker.pose);
  }

  void _applyYaw(YawReading? yaw) {
    _yaw = yaw;
    _tracker?.updateYaw(yaw?.value, absolute: yaw?.absolute ?? false);
  }

  void _update({int? nextProductIndex, int? collected, int steps = 0}) {
    state = NavigationSession(
      plan: state.plan,
      nextProductIndex: nextProductIndex ?? state.nextProductIndex,
      collected: collected ?? state.collected,
      pose: _tracker?.pose,
      steps: state.steps + steps,
    );
  }

  /// Cada paso avanza sobre la ruta hasta la parada pendiente: la persona
  /// confirma cada producto con los botones de la parada.
  void registerSteps(int steps, YawReading? yaw) {
    final plan = state.plan;
    final tracker = _tracker;
    if (plan == null || tracker == null || state.current == null) return;
    final limit = plan.productDistances[state.nextProductIndex];
    _applyYaw(yaw);
    for (var step = 0; step < steps; step++) {
      tracker.followStep(limit: limit);
    }
    _update(steps: steps);
  }

  /// Giro sin caminar. No cambia el estado para no reconstruir la pantalla varias
  /// veces por segundo: devuelve la pose para enviarla directo al visor.
  WalkerPose? updateYaw(YawReading yaw) {
    _applyYaw(yaw);
    return _tracker?.pose;
  }

  /// La persona indica que mira hacia donde sigue la ruta.
  void recenter() {
    _tracker?.recenter();
    _update();
  }

  void advance({required bool collected}) {
    final plan = state.plan;
    final tracker = _tracker;
    if (plan == null || tracker == null || state.current == null) return;
    // Confirmar una parada ubica a la persona allí y corrige el error acumulado.
    final stop = plan.productDistances[state.nextProductIndex];
    tracker.moveTo(stop > tracker.walked ? stop : tracker.walked);
    _update(
      nextProductIndex: state.nextProductIndex + 1,
      collected: state.collected + (collected ? 1 : 0),
    );
  }

  void restart() {
    final plan = state.plan;
    if (plan == null) return;
    start(plan, northDegrees: _northDegrees);
  }

  void clear() {
    _tracker = null;
    state = const NavigationSession();
  }
}
