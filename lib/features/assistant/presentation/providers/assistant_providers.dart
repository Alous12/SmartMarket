import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../app/providers/store_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../store_navigation/presentation/providers/store_model_provider.dart';
import '../../../users/data/user_api.dart' show apiBaseUrl;
import '../../data/assistant_api.dart';
import '../../domain/entities/assistant_request.dart';

final assistantApiProvider = Provider<AssistantApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AssistantApi(client: client, baseUri: Uri.parse(apiBaseUrl));
});

final assistantModelsProvider =
    FutureProvider.autoDispose<List<AssistantModel>>((ref) async {
      final session = await ref.watch(authControllerProvider.future);
      if (session == null) {
        throw const AssistantApiException(
          'Inicia sesión para elegir un modelo.',
        );
      }
      return ref.watch(assistantApiProvider).fetchModels(token: session.token);
    }, retry: (count, error) => null);

/// Sucursal del supermercado elegido en el mapa, donde se comprará la receta.
/// Es null si no se pudo consultar.
final assistantBranchIdProvider = FutureProvider.autoDispose<int?>((ref) async {
  final store = ref.watch(selectedStoreProvider);
  try {
    return await ref.watch(catalogApiProvider).branchIdFor(store.assetPath);
  } on Object {
    return null;
  }
});

/// Recetas que el usuario ya pidió.
final recipeHistoryProvider =
    FutureProvider.autoDispose<List<RecipeHistoryEntry>>((ref) async {
      final session = await ref.watch(authControllerProvider.future);
      if (session == null) return const [];
      return ref.watch(assistantApiProvider).fetchHistory(token: session.token);
    }, retry: (count, error) => null);

/// Cada cuánto se consulta si la IA terminó de procesar la petición.
final assistantPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);
