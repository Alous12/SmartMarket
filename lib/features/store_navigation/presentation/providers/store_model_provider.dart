import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/store_providers.dart';
import '../../domain/entities/store_model.dart';

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
