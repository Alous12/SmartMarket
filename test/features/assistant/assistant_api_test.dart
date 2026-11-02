import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmarket/features/assistant/data/assistant_api.dart';
import 'package:smartmarket/features/assistant/domain/entities/assistant_request.dart';

void main() {
  group('AssistantApi', () {
    test(
      'envía la petición sin modificaciones y con el token de sesión',
      () async {
        const prompt = '  Quiero preparar lasaña para 4 personas 🍝\ny pan  ';
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url,
            Uri.parse('http://localhost:3000/api/assistant/requests'),
          );
          expect(request.headers['Authorization'], 'Bearer signed-token');
          expect(jsonDecode(request.body), {'prompt': prompt});
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'data': {
                  'request_id': 12,
                  'user_id': 1,
                  'prompt': prompt,
                  'status': 'PROCESSING',
                },
              }),
            ),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        final api = AssistantApi(
          client: client,
          baseUri: Uri.parse('http://localhost:3000/api/'),
        );

        final request = await api.sendRequest(
          token: 'signed-token',
          prompt: prompt,
        );

        expect(request.id, 12);
        expect(request.prompt, prompt);
        expect(request.status, AssistantRequestStatus.processing);
      },
    );

    test('muestra el mensaje de error que devuelve el backend', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'error': 'Token inválido o expirado.'}),
          401,
        ),
      );
      final api = AssistantApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
      );

      expect(
        () => api.sendRequest(token: 'expired', prompt: 'pan'),
        throwsA(
          isA<AssistantApiException>().having(
            (error) => error.message,
            'message',
            'Token inválido o expirado.',
          ),
        ),
      );
    });

    test('informa cuando no puede conectarse con el backend', () async {
      final client = MockClient(
        (request) async => throw http.ClientException('sin conexión'),
      );
      final api = AssistantApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
      );

      expect(
        () => api.sendRequest(token: 'signed-token', prompt: 'pan'),
        throwsA(isA<AssistantApiException>()),
      );
    });

    test('envía el supermercado elegido junto con la petición', () async {
      final client = MockClient((request) async {
        expect(jsonDecode(request.body), {'prompt': 'lasaña', 'branch_id': 2});
        return http.Response(
          jsonEncode({
            'data': {
              'request_id': 3,
              'prompt': 'lasaña',
              'status': 'PROCESSING',
            },
          }),
          201,
        );
      });
      final api = AssistantApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
      );

      final request = await api.sendRequest(
        token: 'signed-token',
        prompt: 'lasaña',
        branchId: 2,
      );
      expect(request.isFinished, isFalse);
    });

    test(
      'HU-16: consulta la receta identificada y su lista de ingredientes',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url,
            Uri.parse('http://localhost:3000/api/assistant/requests/12'),
          );
          expect(request.headers['Authorization'], 'Bearer signed-token');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'data': {
                  'request_id': 12,
                  'prompt': 'Quiero preparar lasaña',
                  'status': 'COMPLETED',
                  'recipe_name': 'Lasaña de carne',
                  'response_message': null,
                  'ingredients': [
                    {
                      'ingredient_id': 26,
                      'name': 'Carne molida',
                      'quantity': 500,
                      'unit': 'g',
                    },
                    {
                      'ingredient_id': null,
                      'name': 'Nuez moscada',
                      'quantity': null,
                      'unit': null,
                    },
                  ],
                },
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        final api = AssistantApi(
          client: client,
          baseUri: Uri.parse('http://localhost:3000/api'),
        );

        final request = await api.fetchRequest(
          token: 'signed-token',
          requestId: 12,
        );

        expect(request.status, AssistantRequestStatus.completed);
        expect(request.isFinished, isTrue);
        expect(request.recipeName, 'Lasaña de carne');
        expect(request.ingredients.map((item) => item.name), [
          'Carne molida',
          'Nuez moscada',
        ]);
        expect(request.ingredients.first.quantity, 500);
        expect(request.ingredients.first.unit, 'g');
        expect(request.ingredients.first.inCatalog, isTrue);
        expect(request.ingredients.last.quantity, isNull);
        expect(request.ingredients.last.inCatalog, isFalse);
      },
    );
  });
}
