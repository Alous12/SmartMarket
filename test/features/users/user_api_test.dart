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

    test('envía el token Bearer al listar usuarios', () async {
      final client = MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer staff-token');
        return http.Response(jsonEncode({'data': []}), 200);
      });
      final api = UserApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
        tokenReader: () async => 'staff-token',
      );

      expect(await api.getUsers(), isEmpty);
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

    test(
      'perfil: lee, actualiza solo lo indicado y cambia la contraseña',
      () async {
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          expect(request.headers['authorization'], 'Bearer t');
          if (request.method == 'PUT') return http.Response('', 204);
          return http.Response(
            jsonEncode({
              'data': {
                'user_id': 7,
                'name': 'Ana',
                'last_name': 'Pérez',
                'email': 'ana@example.com',
                'role': 'admin',
                'status': true,
              },
            }),
            200,
          );
        });
        final api = UserApi(
          client: client,
          baseUri: Uri.parse('http://localhost:3000/api/'),
          tokenReader: () async => 't',
        );

        expect((await api.getProfile()).role, 'admin');
        await api.updateProfile(lastName: 'Gómez');
        await api.changePassword(
          currentPassword: 'a1234567',
          newPassword: 'b1234567',
        );

        expect(requests.map((r) => '${r.method} ${r.url.path}'), [
          'GET /api/users/me',
          'PATCH /api/users/me',
          'PUT /api/users/me/password',
        ]);
        expect(jsonDecode(requests[1].body), {'last_name': 'Gómez'});
        client.close();
      },
    );

    test('perfil: muestra el mensaje del servidor si falla', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'error': 'La contraseña actual no es correcta.'}),
          400,
        ),
      );
      final api = UserApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
      );

      await expectLater(
        api.changePassword(currentPassword: 'x', newPassword: 'y1234567'),
        throwsA(
          isA<UserApiException>().having(
            (e) => e.message,
            'message',
            'La contraseña actual no es correcta.',
          ),
        ),
      );
      client.close();
    });
  });
}
