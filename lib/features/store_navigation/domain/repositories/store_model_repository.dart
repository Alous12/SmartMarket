import '../entities/store_model.dart';

abstract interface class StoreModelRepository {
  Future<StoreModel> load();
}
