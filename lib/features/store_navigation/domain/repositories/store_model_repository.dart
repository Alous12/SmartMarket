import '../entities/store_model.dart';

abstract interface class StoreModelRepository {
  Future<StoreModel> load(Supermarket store);
}

abstract interface class ProductNamesRepository {
  Future<Map<String, String>> load(Supermarket store);
  Future<void> save(Supermarket store, Map<String, String> names);
}
