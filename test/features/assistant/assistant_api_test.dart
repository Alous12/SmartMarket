import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmarket/features/assistant/data/assistant_api.dart';
import 'package:smartmarket/features/assistant/domain/entities/assistant_request.dart';
import 'package:smartmarket/features/assistant/domain/entities/recipe_availability.dart';

void main() {
  group('AssistantApi', () {
    test('consulta modelos y envía el modelo seleccionado', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          expect(request.url.path, '/api/assistant/models');
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'ollama:gemma4:12b', 'label': 'Ollama (gemma4:12b)'},
              ],
            }),
            200,
          );
        }
        expect(jsonDecode(request.body), {
          'prompt': 'lasaña',
          'model_id': 'ollama:gemma4:12b',
        });
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
      expect(
        (await api.fetchModels(token: 'signed-token')).single.id,
        'ollama:gemma4:12b',
      );
      await api.sendRequest(
        token: 'signed-token',
        prompt: 'lasaña',
        modelId: 'ollama:gemma4:12b',
      );
    });

    test('selecciona un producto y recibe la elección actualizada', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(
          request.url.path,
          '/api/assistant/requests/7/ingredients/3/product',
        );
        expect(jsonDecode(request.body), {'branch_id': 1, 'product_id': 30});
        return http.Response(
          jsonEncode({
            'data': {
              'branch_id': 1,
              'items': [
                {
                  'item_id': 3,
                  'name': 'Leche',
                  'availability': 'AVAILABLE',
                  'other_branches': [],
                  'substitutes': [],
                  'product_options': [
                    {
                      'product_id': 30,
                      'branch_id': 1,
                      'branch_name': 'Natural',
                      'name': 'Leche',
                      'price': 10.5,
                      'unit_of_measure': 'l',
                      'ingredient_name': 'Leche',
                      'is_substitute': false,
                      'selected': true,
                    },
                  ],
                },
              ],
              'routes': [],
            },
          }),
          200,
        );
      });
      final api = AssistantApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
      );
      final result = await api.selectProduct(
        token: 'signed-token',
        requestId: 7,
        itemId: 3,
        branchId: 1,
        productId: 30,
      );
      expect(result.items.single.productOptions.single.selected, isTrue);
      expect(result.items.single.productOptions.single.price, 10.5);
    });

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

    test('consulta la disponibilidad y la ruta de la petición', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/api/assistant/requests/7/ingredients/availability',
        );
        expect(request.headers['Authorization'], 'Bearer signed-token');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'data': {
                'branch_id': 1,
                'branch_name': 'Supermercado Natural',
                'items': [
                  {
                    'item_id': 3,
                    'name': 'Leche',
                    'availability': 'AVAILABLE',
                    'available_products': [
                      {'name': 'Leche', 'section_name': 'LACTEOS'},
                    ],
                    'other_branches': [],
                    'substitutes': [],
                  },
                  {
                    'item_id': 4,
                    'name': 'Azafrán',
                    'availability': 'NOT_IN_CATALOG',
                    'available_products': [],
                    'other_branches': [],
                    'substitutes': [],
                  },
                ],
                'routes': [
                  {
                    'branch_id': 1,
                    'branch_name': 'Supermercado Natural',
                    'model_3d_url': 'Modelos_3D/supermercado_1.glb',
                    'stops': [
                      {
                        'item_id': 3,
                        'ingredient_name': 'Leche',
                        'product_id': 30,
                        'product_name': 'Leche',
                        'section_name': 'LACTEOS',
                        'is_substitute': false,
                      },
                    ],
                    'missing': ['Azafrán'],
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

      final availability = await api.fetchAvailability(
        token: 'signed-token',
        requestId: 7,
      );

      expect(availability.items.first.status, IngredientStatus.available);
      expect(availability.items.last.status, IngredientStatus.notInCatalog);
      expect(availability.nowhere.single.name, 'Azafrán');
      expect(availability.routes.single.stops.single.productId, 30);
      expect(availability.routes.single.missing, ['Azafrán']);
    });

    test('consulta el historial de recetas', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/assistant/requests');
        expect(request.headers['Authorization'], 'Bearer signed-token');
        return http.Response(
          jsonEncode({
            'data': [
              {
                'request_id': 15,
                'recipe_name': 'Silpancho',
                'branch_id': 1,
                'ingredient_count': 11,
                'created_at': '2026-11-02T12:00:00.000Z',
              },
            ],
          }),
          200,
        );
      });
      final api = AssistantApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
      );

      final history = await api.fetchHistory(token: 'signed-token');

      expect(history.single.id, 15);
      expect(history.single.recipeName, 'Silpancho');
      expect(history.single.ingredientCount, 11);
    });

    test('rechaza una disponibilidad con un estado desconocido', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'data': {
              'branch_id': 1,
              'routes': [],
              'items': [
                {
                  'item_id': 1,
                  'name': 'Sal',
                  'availability': 'RARO',
                  'available_products': [],
                  'other_branches': [],
                  'substitutes': [],
                },
              ],
            },
          }),
          200,
        ),
      );
      final api = AssistantApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
      );

      await expectLater(
        api.fetchAvailability(token: 'signed-token', requestId: 7),
        throwsA(isA<AssistantApiException>()),
      );
    });
  });
}
