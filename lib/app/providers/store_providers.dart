import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/data/auth_api.dart' show PreferencesAuthTokenStorage;
import '../../features/store_navigation/data/catalog_api.dart';
import '../../features/store_navigation/data/repositories/asset_store_model_repository.dart';
import '../../features/users/data/user_api.dart' show apiBaseUrl;
import '../../features/store_navigation/data/repositories/preferences_product_names_repository.dart';
import '../../features/store_navigation/domain/repositories/store_model_repository.dart';

final storeModelRepositoryProvider = Provider<StoreModelRepository>(
  (ref) => AssetStoreModelRepository(),
);

final catalogApiProvider = Provider<CatalogApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return CatalogApi(
    client: client,
    baseUri: Uri.parse(apiBaseUrl),
    tokenReader: PreferencesAuthTokenStorage().read,
  );
});

final productNamesRepositoryProvider = Provider<ProductNamesRepository>(
  (ref) => PreferencesProductNamesRepository(),
);
