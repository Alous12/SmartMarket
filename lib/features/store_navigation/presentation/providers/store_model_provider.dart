import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/store_providers.dart';
import '../../data/catalog_api.dart';
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

/// Modelo 3D con los datos de producto (nombre, categoría, precio y stock)
/// de la base de datos. Si el backend no responde, se usan los del modelo.
final storeModelProvider = FutureProvider.autoDispose<StoreModel>((ref) async {
  final store = ref.watch(selectedStoreProvider);
  final model = await ref.watch(storeModelRepositoryProvider).load(store);
  final Map<String, CatalogProduct> catalog;
  try {
    catalog = await ref.watch(catalogApiProvider).loadProducts(store.assetPath);
  } on Object {
    return model;
  }
  final products = [
    for (final product in model.metadata.products)
      if (catalog[product.id] case final data?)
        product.copyWith(
          name: data.name,
          category: data.category,
          price: data.price,
          stock: data.stock,
          dbId: data.productId,
        ),
  ];
  return StoreModel(
    store: model.store,
    bytes: model.bytes,
    metadata: model.metadata.withProducts(products),
    fromCatalog: true,
  );
}, retry: (count, error) => null);

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
    this.nextProductIndex = 0,
    this.collected = 0,
  });

  final StoreRoutePlan? plan;
  final int nextProductIndex;
  final int collected;

  List<StoreProduct> get stops => plan?.products ?? const [];
  StoreProduct? get current =>
      nextProductIndex < stops.length ? stops[nextProductIndex] : null;
  int get pending => stops.length - nextProductIndex;
}

class NavigationSessionNotifier extends Notifier<NavigationSession> {
  @override
  NavigationSession build() => const NavigationSession();

  void start(StoreRoutePlan plan) => state = NavigationSession(plan: plan);

  void advance({required bool collected}) {
    if (state.current == null) return;
    state = NavigationSession(
      plan: state.plan,
      nextProductIndex: state.nextProductIndex + 1,
      collected: state.collected + (collected ? 1 : 0),
    );
  }

  void restart() {
    if (state.plan != null) state = NavigationSession(plan: state.plan);
  }

  void clear() => state = const NavigationSession();
}
