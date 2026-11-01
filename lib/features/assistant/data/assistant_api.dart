import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/entities/assistant_request.dart';

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

  /// Envía el texto tal como lo escribió el usuario.
  Future<AssistantRequest> sendRequest({
    required String token,
    required String prompt,
  }) async {
    http.Response response;
    try {
      response = await _client
          .post(
            _requestsUri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(_timeout);
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
      throw AssistantApiException(
        error is String ? error : 'No se pudo enviar tu petición.',
      );
    }

    try {
      return AssistantRequest.fromJson(decoded['data'] as Map<String, dynamic>);
    } on Object {
      throw const AssistantApiException(
        'El servidor devolvió una petición inválida.',
      );
    }
  }
}
