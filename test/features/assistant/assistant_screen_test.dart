import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmarket/core/theme/app_theme.dart';
import 'package:smartmarket/features/assistant/data/assistant_api.dart';
import 'package:smartmarket/features/assistant/presentation/providers/assistant_providers.dart';
import 'package:smartmarket/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:smartmarket/features/auth/data/auth_api.dart';
import 'package:smartmarket/features/auth/presentation/providers/auth_provider.dart';

class _SignedInController extends AuthController {
  @override
  Future<AuthSession?> build() async =>
      const AuthSession(token: 'signed-token', username: 'Ana', role: 'user');
}

Future<void> _pumpAssistant(
  WidgetTester tester, {
  MockClientHandler? handler,
}) async {
  final client = MockClient(
    handler ?? (request) async => fail('No debería enviarse ninguna petición'),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_SignedInController.new),
        assistantApiProvider.overrideWithValue(
          AssistantApi(
            client: client,
            baseUri: Uri.parse('http://localhost:3000/api'),
          ),
        ),
        assistantBranchIdProvider.overrideWith((ref) async => 2),
        assistantPollIntervalProvider.overrideWithValue(Duration.zero),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const AssistantScreen()),
    ),
  );
  await tester.pump();
}

http.Response _json(Map<String, Object?> data, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode({'data': data})),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _created(String prompt) => _json({
  'request_id': 1,
  'user_id': 1,
  'prompt': prompt,
  'status': 'PROCESSING',
}, 201);

/// Responde el envío y luego cada consulta con el siguiente estado de [states].
MockClientHandler _assistant(
  List<Map<String, Object?>> states, {
  List<Map<String, dynamic>>? sentBodies,
}) {
  var polls = 0;
  return (request) async {
    if (request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      sentBodies?.add(body);
      return _created(body['prompt'] as String);
    }
    expect(request.url.path, '/api/assistant/requests/1');
    final state = states[polls < states.length ? polls : states.length - 1];
    polls++;
    return _json({'request_id': 1, 'prompt': 'x', ...state}, 200);
  };
}

const _lasagna = {
  'status': 'COMPLETED',
  'recipe_name': 'Lasaña de carne',
  'ingredients': [
    {
      'ingredient_id': 48,
      'name': 'Masa para lasaña',
      'quantity': 250,
      'unit': 'g',
    },
    {
      'ingredient_id': 26,
      'name': 'Carne molida',
      'quantity': 0.5,
      'unit': 'kg',
    },
    {'ingredient_id': 42, 'name': 'Sal', 'quantity': null, 'unit': null},
  ],
};

void main() {
  group('HU-10 — Mostrar campo de texto', () {
    testWidgets(
      'CC1: muestra un campo de texto para introducir una solicitud',
      (tester) async {
        await _pumpAssistant(tester);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Escribe un plato o un producto…'), findsOneWidget);
      },
    );

    testWidgets('CC2: el campo permite al usuario ingresar texto', (
      tester,
    ) async {
      await _pumpAssistant(tester);
      await tester.enterText(
        find.byType(TextField),
        'Quiero preparar lasaña para 4 personas',
      );
      await tester.pump();
      expect(
        find.text('Quiero preparar lasaña para 4 personas'),
        findsOneWidget,
      );
    });

    testWidgets('CC3: el campo está disponible antes de enviar una solicitud', (
      tester,
    ) async {
      await _pumpAssistant(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled ?? true, isTrue);
      expect(field.readOnly, isFalse);
      expect(field.controller!.text, isEmpty);
    });
  });

  group('HU-12 — Enviar petición', () {
    testWidgets(
      'CC1 y CC2: envía la petición escrita y el sistema recibe su contenido',
      (tester) async {
        const prompt = 'Quiero preparar lasaña para 4 personas';
        final received = <String>[];
        await _pumpAssistant(
          tester,
          handler: (request) async {
            expect(request.headers['Authorization'], 'Bearer signed-token');
            if (request.method == 'GET') {
              return _json({
                'request_id': 1,
                'prompt': prompt,
                ..._lasagna,
              }, 200);
            }
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            received.add(body['prompt'] as String);
            return _created(body['prompt'] as String);
          },
        );

        await tester.enterText(find.byType(TextField), prompt);
        await tester.tap(find.byTooltip('Enviar'));
        await tester.pumpAndSettle();

        expect(received, [prompt]);
        expect(find.text(prompt), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, isEmpty);
      },
    );

    testWidgets('no envía una petición vacía', (tester) async {
      await _pumpAssistant(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('si falla el envío avisa y conserva el texto escrito', (
      tester,
    ) async {
      await _pumpAssistant(
        tester,
        handler: (request) async => http.Response(
          jsonEncode({'error': 'Token inválido o expirado.'}),
          401,
        ),
      );

      await tester.enterText(find.byType(TextField), 'pan y leche');
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pumpAndSettle();

      expect(find.text('Token inválido o expirado.'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'pan y leche');
    });
  });

  group('HU-14 — Identificar la receta', () {
    testWidgets(
      'CC1 y CC2: la IA recibe la petición sin cambios y con el supermercado elegido',
      (tester) async {
        const prompt = '  Quiero preparar lasaña para 4 personas 🍝 ';
        final sent = <Map<String, dynamic>>[];
        await _pumpAssistant(
          tester,
          handler: _assistant([_lasagna], sentBodies: sent),
        );

        await tester.enterText(find.byType(TextField), prompt);
        await tester.tap(find.byTooltip('Enviar'));
        await tester.pumpAndSettle();

        expect(sent, [
          {'prompt': prompt, 'branch_id': 2},
        ]);
      },
    );

    testWidgets('CC3: muestra que la petición se está procesando', (
      tester,
    ) async {
      await _pumpAssistant(
        tester,
        handler: _assistant([
          {'status': 'PROCESSING', 'recipe_name': null},
          {'status': 'PROCESSING', 'recipe_name': 'Lasaña de carne'},
          _lasagna,
        ]),
      );

      await tester.enterText(find.byType(TextField), 'lasaña');
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Identificando la receta…'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Identificando la receta…'), findsNothing);
      expect(find.text('Lasaña de carne'), findsOneWidget);
    });
  });

  group('HU-15 y HU-16 — Ingredientes en una lista estructurada', () {
    testWidgets(
      'muestra la receta identificada y cada ingrediente por separado',
      (tester) async {
        await _pumpAssistant(tester, handler: _assistant([_lasagna]));

        await tester.enterText(find.byType(TextField), 'lasaña para 4');
        await tester.tap(find.byTooltip('Enviar'));
        await tester.pumpAndSettle();

        expect(find.text('Lasaña de carne'), findsOneWidget);
        expect(find.text('Ingredientes (3)'), findsOneWidget);
        expect(find.text('Masa para lasaña'), findsOneWidget);
        expect(find.text('250 g'), findsOneWidget);
        expect(find.text('Carne molida'), findsOneWidget);
        expect(find.text('0.5 kg'), findsOneWidget);
        expect(find.text('Sal'), findsOneWidget);
        expect(find.text('al gusto'), findsOneWidget);
      },
    );

    testWidgets('si la petición no es una receta muestra el motivo', (
      tester,
    ) async {
      const message = 'Solo puedo ayudarte con recetas.';
      await _pumpAssistant(
        tester,
        handler: _assistant([
          {'status': 'REJECTED', 'response_message': message},
        ]),
      );

      await tester.enterText(find.byType(TextField), 'Escríbeme un poema');
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(find.textContaining('Ingredientes'), findsNothing);
    });

    testWidgets('si la IA falla muestra el mensaje del servidor', (
      tester,
    ) async {
      const message =
          'El asistente alcanzó su límite de consultas. Inténtalo en unos minutos.';
      await _pumpAssistant(
        tester,
        handler: _assistant([
          {'status': 'FAILED', 'response_message': message},
        ]),
      );

      await tester.enterText(find.byType(TextField), 'lasaña');
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
    });
  });
}
