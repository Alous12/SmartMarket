import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmarket/features/auth/data/auth_api.dart';

class _MemoryTokenStorage implements AuthTokenStorage {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> delete() async {
    token = null;
  }
}

void main() {
  group('AuthApi', () {
    test('envía credenciales y persiste el token mínimo de sesión', () async {
      final storage = _MemoryTokenStorage();
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url, Uri.parse('http://localhost:3000/api/auth/login'));
        expect(jsonDecode(request.body), {
          'email': 'ana@example.com',
          'password': 'clave-segura',
        });
        return http.Response(
          jsonEncode({
            'data': {
              'token': 'signed-token',
              'username': 'Ana',
              'role': 'user',
            },
          }),
          200,
        );
      });
      final api = AuthApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
        tokenStorage: storage,
      );

      final session = await api.login(
        email: ' ana@example.com ',
        password: 'clave-segura',
      );

      expect(session.username, 'Ana');
      expect(session.role, 'user');
      expect(storage.token, 'signed-token');
      client.close();
    });

    test('restaura la sesión enviando el token como Bearer', () async {
      final storage = _MemoryTokenStorage()..token = 'signed-token';
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url, Uri.parse('http://localhost:3000/api/auth/me'));
        expect(request.headers['authorization'], 'Bearer signed-token');
        return http.Response(
          jsonEncode({
            'data': {'username': 'Ana', 'role': 'user'},
          }),
          200,
        );
      });
      final api = AuthApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
        tokenStorage: storage,
      );

      final session = await api.restoreSession();

      expect(session?.username, 'Ana');
      expect(session?.token, 'signed-token');
      client.close();
    });
  });
}
