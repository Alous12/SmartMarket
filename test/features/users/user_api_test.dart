import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmarket/features/users/data/user_api.dart';

void main() {
  group('UserApi', () {
    test('obtiene usuarios desde el endpoint y convierte status', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url, Uri.parse('http://localhost:3000/api/users'));
        return http.Response(
          jsonEncode({
            'data': [
              {
                'user_id': 7,
                'name': 'Ana',
                'last_name': 'Pérez',
                'email': 'ana@example.com',
                'role': 'user',
                'status': 1,
              },
            ],
          }),
          200,
        );
      });
      final api = UserApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api/'),
      );

      final users = await api.getUsers();

      expect(users, hasLength(1));
      expect(users.single.id, 7);
      expect(users.single.name, 'Ana');
      expect(users.single.isActive, isTrue);
      client.close();
    });

    test('envía la solicitud de creación con el contrato esperado', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url, Uri.parse('http://localhost:3000/api/users'));
        expect(request.headers['content-type'], 'application/json');
        expect(jsonDecode(request.body), {
          'name': 'Ana',
          'last_name': 'Pérez',
          'email': 'ana@example.com',
          'password': 'clave-segura',
        });
        return http.Response(
          jsonEncode({
            'data': {
              'user_id': 7,
              'name': 'Ana',
              'last_name': 'Pérez',
              'email': 'ana@example.com',
              'role': 'user',
              'status': true,
            },
          }),
          201,
        );
      });
      final api = UserApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
      );

      final user = await api.createUser(
        name: 'Ana',
        lastName: 'Pérez',
        email: 'ana@example.com',
        password: 'clave-segura',
      );

      expect(user.id, 7);
      client.close();
    });

    test('expone el error del backend en vez de esconderlo', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'error': 'El correo electrónico ya está registrado.'}),
          409,
        ),
      );
      final api = UserApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
      );

      await expectLater(
        api.getUsers(),
        throwsA(
          isA<UserApiException>().having(
            (error) => error.message,
            'message',
            'El correo electrónico ya está registrado.',
          ),
        ),
      );
      client.close();
    });
  });
}
