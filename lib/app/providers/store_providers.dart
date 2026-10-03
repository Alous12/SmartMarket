import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/store_navigation/data/repositories/asset_store_model_repository.dart';
import '../../features/store_navigation/data/repositories/preferences_product_names_repository.dart';
import '../../features/store_navigation/domain/repositories/store_model_repository.dart';

final storeModelRepositoryProvider = Provider<StoreModelRepository>(
  (ref) => AssetStoreModelRepository(),
);

final productNamesRepositoryProvider = Provider<ProductNamesRepository>(
  (ref) => PreferencesProductNamesRepository(),
);
