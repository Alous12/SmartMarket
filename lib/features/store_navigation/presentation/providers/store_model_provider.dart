import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/store_providers.dart';
import '../../domain/entities/store_model.dart';
import '../../domain/services/store_route_planner.dart';

/// Supermercado elegido con los botones de la pantalla.
final selectedStoreProvider = NotifierProvider<SelectedStoreNotifier, Supermarket>(
  SelectedStoreNotifier.new,
);

class SelectedStoreNotifier extends Notifier<Supermarket> {
  @override
  Supermarket build() => Supermarket.natural;

  void select(Supermarket store) => state = store;
}

final storeModelProvider = FutureProvider.autoDispose<StoreModel>(
  (ref) => ref
      .watch(storeModelRepositoryProvider)
      .load(ref.watch(selectedStoreProvider)),
  retry: (count, error) => null,
);

/// Nombres editados del supermercado elegido (product_id -> nombre).
final productNamesProvider =
    AsyncNotifierProvider.autoDispose<ProductNamesNotifier, Map<String, String>>(
      ProductNamesNotifier.new,
    );

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
    this.currentLeg,
    this.nextProductIndex = 0,
    this.collected = 0,
  });

  final StoreRoutePlan? plan;
  final StoreRoutePlan? currentLeg;
  final int nextProductIndex;
  final int collected;

  List<StoreProduct> get stops => plan?.products ?? const [];
  StoreProduct? get current =>
      nextProductIndex < stops.length ? stops[nextProductIndex] : null;
  int get pending => stops.length - nextProductIndex;

  /// Únicamente el tramo hacia el producto actual. Al avanzar, el origen pasa
  /// a ser la parada anterior y se expone el siguiente tramo.
  StoreRoutePlan? get remainingPlan {
    if (currentLeg != null) return currentLeg;
    final activePlan = plan;
    final currentProduct = current;
    if (activePlan == null || currentProduct == null) return null;
    final originNode = nextProductIndex == 0
        ? activePlan.nodeIds.first
        : stops[nextProductIndex - 1].routeNode;
    final pathStart = activePlan.nodeIds.indexOf(originNode);
    if (pathStart < 0) return null;
    final destinationIndex = activePlan.nodeIds.indexOf(
      currentProduct.routeNode,
      pathStart,
    );
    if (destinationIndex < pathStart) return null;
    return StoreRoutePlan(
      nodeIds: List.unmodifiable(
        activePlan.nodeIds.sublist(pathStart, destinationIndex + 1),
      ),
      stopNodeIds: List.unmodifiable([currentProduct.routeNode]),
      products: List.unmodifiable([currentProduct]),
      distance: activePlan.distance,
    );
  }
}

class NavigationSessionNotifier extends Notifier<NavigationSession> {
  @override
  NavigationSession build() => const NavigationSession();

  void start(StoreRoutePlan plan) => state = NavigationSession(plan: plan);

  void advance({required bool collected}) {
    if (state.current == null) return;
    state = NavigationSession(
      plan: state.plan,
      currentLeg: null,
      nextProductIndex: state.nextProductIndex + 1,
      collected: state.collected + (collected ? 1 : 0),
    );
  }

  void showCurrentLeg(StoreRoutePlan leg) {
    state = NavigationSession(
      plan: state.plan,
      currentLeg: leg,
      nextProductIndex: state.nextProductIndex,
      collected: state.collected,
    );
  }

  void restart() {
    if (state.plan != null) state = NavigationSession(plan: state.plan);
  }

  void clear() => state = const NavigationSession();
}
