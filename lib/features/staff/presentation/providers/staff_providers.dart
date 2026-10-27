import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_api.dart' show PreferencesAuthTokenStorage;
import '../../../users/data/user_api.dart' show apiBaseUrl;
import '../../data/staff_api.dart';

final staffApiProvider = Provider<StaffApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return StaffApi(
    client: client,
    baseUri: Uri.parse(apiBaseUrl),
    tokenReader: PreferencesAuthTokenStorage().read,
  );
});

final staffOptionsProvider = FutureProvider.autoDispose<StaffOptions>(
  (ref) => ref.watch(staffApiProvider).getOptions(),
);

final staffProductsProvider = FutureProvider.autoDispose<List<ProductLocation>>(
  (ref) => ref.watch(staffApiProvider).getProducts(),
);
