import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/entities/user.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000/api',
);

class UserApiException implements Exception {
  const UserApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UserApi {
  UserApi({required http.Client client, required Uri baseUri})
    : this._internal(client, baseUri);

  UserApi._internal(this._client, Uri baseUri)
    : _usersUri = Uri.parse(
        '${baseUri.toString().replaceFirst(RegExp(r'/+$'), '')}/users',
      );

  final http.Client _client;
  final Uri _usersUri;
  static const _timeout = Duration(seconds: 10);

  Future<List<User>> getUsers() async {
    final response = await _send(() => _client.get(_usersUri));
    final body = _decodeResponse(response);
    final data = body['data'];
    if (data is! List) {
      throw const UserApiException('El servidor devolvió una lista inválida.');
    }

    try {
      return data
          .map((item) => User.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on Object {
      throw const UserApiException('El servidor devolvió usuarios inválidos.');
    }
  }

  Future<User> createUser({
    required String name,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final response = await _send(
      () => _client.post(
        _usersUri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'last_name': lastName,
          'email': email,
          'password': password,
        }),
      ),
    );
    final body = _decodeResponse(response);
    try {
      return User.fromJson(body['data'] as Map<String, dynamic>);
    } on Object {
      throw const UserApiException('El servidor devolvió un usuario inválido.');
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() send) async {
    try {
      return await send().timeout(_timeout);
    } on SocketException {
      throw const UserApiException(
        'No se pudo conectar con el backend. Verifica la URL y que el servidor esté activo.',
      );
    } on http.ClientException {
      throw const UserApiException(
        'No se pudo conectar con el backend. Verifica la URL y que el servidor esté activo.',
      );
    } on TimeoutException {
      throw const UserApiException(
        'El backend tardó demasiado en responder. Inténtalo de nuevo.',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const UserApiException(
        'El servidor devolvió una respuesta inválida.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const UserApiException(
        'El servidor devolvió una respuesta inválida.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      throw UserApiException(
        error is String
            ? error
            : 'La solicitud falló (${response.statusCode}).',
      );
    }
    return decoded;
  }
}
