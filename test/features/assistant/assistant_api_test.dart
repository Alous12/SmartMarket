import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmarket/features/assistant/data/assistant_api.dart';
import 'package:smartmarket/features/assistant/domain/entities/assistant_request.dart';

void main() {
  group('AssistantApi', () {
    test('envía la petición sin modificaciones y con el token de sesión', () async {
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
    });

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
  });
}
