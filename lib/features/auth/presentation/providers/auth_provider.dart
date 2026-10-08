import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../users/data/user_api.dart' show apiBaseUrl;
import '../../../users/presentation/providers/users_providers.dart'
    show userApiProvider;
import '../../data/auth_api.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AuthApi(client: client, baseUri: Uri.parse(apiBaseUrl));
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  AuthApi get _api => ref.read(authApiProvider);

  @override
  Future<AuthSession?> build() => _api.restoreSession();

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _api.login(email: email, password: password),
    );
  }

  Future<void> register({
    required String name,
    required String lastName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(userApiProvider).createUser(
        name: name,
        lastName: lastName,
        email: email,
        password: password,
      );
      return _api.login(email: email, password: password);
    });
  }

  Future<void> logout() async {
    await _api.logout();
    state = const AsyncData(null);
  }
}
