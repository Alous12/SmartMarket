import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.username,
    required this.role,
  });

  final String token;
  final String username;
  final String role;

  factory AuthSession.fromJson(Map<String, dynamic> json, {String? token}) {
    final accessToken = token ?? json['token'];
    final username = json['username'];
    final role = json['role'];
    if (accessToken is! String ||
        username is! String ||
        role is! String ||
        (role != 'user' && role != 'admin')) {
      throw const AuthApiException('El servidor devolvió una sesión inválida.');
    }
    return AuthSession(token: accessToken, username: username, role: role);
  }
}

abstract interface class AuthTokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class PreferencesAuthTokenStorage implements AuthTokenStorage {
  static const _tokenKey = 'smartmarket.auth.token';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_tokenKey);
  }

  @override
  Future<void> write(String token) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = await preferences.setString(_tokenKey, token);
    if (!stored) {
      throw const AuthApiException(
        'No se pudo guardar la sesión en el dispositivo.',
      );
    }
  }

  @override
  Future<void> delete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }
}

class AuthApi {
  AuthApi({
    required http.Client client,
    required Uri baseUri,
    AuthTokenStorage? tokenStorage,
  }) : _client = client,
       _tokenStorage = tokenStorage ?? PreferencesAuthTokenStorage(),
       _loginUri = Uri.parse(
         '${baseUri.toString().replaceFirst(RegExp(r'/+$'), '')}/auth/login',
       ),
       _meUri = Uri.parse(
         '${baseUri.toString().replaceFirst(RegExp(r'/+$'), '')}/auth/me',
       );

  final http.Client _client;
  final AuthTokenStorage _tokenStorage;
  final Uri _loginUri;
  final Uri _meUri;
  static const _timeout = Duration(seconds: 10);

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final body = await _send(
      () => _client.post(
        _loginUri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ),
    );
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const AuthApiException('El servidor devolvió una sesión inválida.');
    }
    final session = AuthSession.fromJson(data);
    await _tokenStorage.write(session.token);
    return session;
  }

  Future<AuthSession?> restoreSession() async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) return null;

    try {
      final body = await _send(
        () => _client.get(_meUri, headers: {'Authorization': 'Bearer $token'}),
      );
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw const AuthApiException(
          'El servidor devolvió una sesión inválida.',
        );
      }
      return AuthSession.fromJson(data, token: token);
    } on AuthApiException catch (error) {
      if (error.message == 'Token inválido o expirado.' ||
          error.message == 'Se requiere un token de acceso.') {
        await _tokenStorage.delete();
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() => _tokenStorage.delete();

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() send,
  ) async {
    http.Response response;
    try {
      response = await send().timeout(_timeout);
    } on SocketException {
      throw const AuthApiException(
        'No se pudo conectar con el backend. Verifica que esté activo.',
      );
    } on http.ClientException {
      throw const AuthApiException(
        'No se pudo conectar con el backend. Verifica que esté activo.',
      );
    } on TimeoutException {
      throw const AuthApiException(
        'El backend tardó demasiado en responder. Inténtalo de nuevo.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AuthApiException(
        'El servidor devolvió una respuesta inválida.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AuthApiException(
        'El servidor devolvió una respuesta inválida.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      throw AuthApiException(
        error is String ? error : 'No se pudo completar la solicitud.',
      );
    }
    return decoded;
  }
}
