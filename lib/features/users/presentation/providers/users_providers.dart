import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_api.dart' show PreferencesAuthTokenStorage;
import '../../data/user_api.dart';
import '../../domain/entities/user.dart';

final userApiProvider = Provider<UserApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return UserApi(
    client: client,
    baseUri: Uri.parse(apiBaseUrl),
    tokenReader: PreferencesAuthTokenStorage().read,
  );
});

final usersProvider = FutureProvider<List<User>>((ref) {
  return ref.watch(userApiProvider).getUsers();
});
