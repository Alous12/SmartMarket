import '../entities/store_model.dart';

abstract interface class StoreModelRepository {
  Future<StoreModel> load(Supermarket store);
}

/// Nombres de producto cambiados desde la app, por supermercado
/// (product_id -> nombre). No modifica el GLB ni el .blend.
abstract interface class ProductNamesRepository {
  Future<Map<String, String>> load(Supermarket store);
  Future<void> save(Supermarket store, Map<String, String> names);
}
