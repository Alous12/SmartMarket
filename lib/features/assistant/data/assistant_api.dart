import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/entities/assistant_request.dart';
import '../domain/entities/recipe_availability.dart';

class AssistantApiException implements Exception {
  const AssistantApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AssistantApi {
  AssistantApi({required http.Client client, required Uri baseUri})
    : this._internal(client, baseUri);

  AssistantApi._internal(this._client, Uri baseUri)
    : _requestsUri = Uri.parse(
        '${baseUri.toString().replaceFirst(RegExp(r'/+$'), '')}/assistant/requests',
      );

  final http.Client _client;
  final Uri _requestsUri;
  static const _timeout = Duration(seconds: 10);

  /// Envía el texto tal como lo escribió el usuario, junto con el
  /// supermercado donde comprará los ingredientes.
  Future<AssistantRequest> sendRequest({
    required String token,
    required String prompt,
    int? branchId,
  }) {
    return _send(
      () => _client.post(
        _requestsUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'prompt': prompt, 'branch_id': ?branchId}),
      ),
      parse: (data) => AssistantRequest.fromJson(_object(data)),
      fallback: 'No se pudo enviar tu petición.',
    );
  }

  /// Consulta el estado de la petición y, cuando la IA termina, la receta
  /// identificada y su lista de ingredientes.
  Future<AssistantRequest> fetchRequest({
    required String token,
    required int requestId,
  }) {
    return _send(
      () => _client.get(
        _requestsUri.replace(path: '${_requestsUri.path}/$requestId'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      parse: (data) => AssistantRequest.fromJson(_object(data)),
      fallback: 'No se pudo consultar tu petición.',
    );
  }

  /// Compara la lista de la petición con el inventario y devuelve qué hay en
  /// cada supermercado y la ruta sugerida.
  Future<RecipeAvailability> fetchAvailability({
    required String token,
    required int requestId,
  }) {
    return _send(
      () => _client.get(
        _requestsUri.replace(
          path: '${_requestsUri.path}/$requestId/ingredients/availability',
        ),
        headers: {'Authorization': 'Bearer $token'},
      ),
      parse: (data) => RecipeAvailability.fromJson(_object(data)),
      fallback: 'No se pudo consultar el inventario.',
    );
  }

  /// Recetas que el usuario ya pidió, de la más nueva a la más antigua.
  Future<List<RecipeHistoryEntry>> fetchHistory({required String token}) {
    return _send(
      () => _client.get(
        _requestsUri,
        headers: {'Authorization': 'Bearer $token'},
      ),
      parse: (data) => [
        for (final entry in data as List) RecipeHistoryEntry.fromJson(_object(entry)),
      ],
      fallback: 'No se pudo cargar el historial.',
    );
  }

  static Map<String, dynamic> _object(Object? data) =>
      data as Map<String, dynamic>;

  Future<T> _send<T>(
    Future<http.Response> Function() send, {
    required T Function(Object? data) parse,
    required String fallback,
  }) async {
    http.Response response;
    try {
      response = await send().timeout(_timeout);
    } on SocketException {
      throw const AssistantApiException(
        'No se pudo conectar con el backend. Verifica que esté activo.',
      );
    } on http.ClientException {
      throw const AssistantApiException(
        'No se pudo conectar con el backend. Verifica que esté activo.',
      );
    } on TimeoutException {
      throw const AssistantApiException(
        'El backend tardó demasiado en responder. Inténtalo de nuevo.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AssistantApiException(
        'El servidor devolvió una respuesta inválida.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AssistantApiException(
        'El servidor devolvió una respuesta inválida.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      throw AssistantApiException(error is String ? error : fallback);
    }

    try {
      return parse(decoded['data']);
    } on Object {
      throw const AssistantApiException(
        'El servidor devolvió una respuesta inválida.',
      );
    }
  }
}
