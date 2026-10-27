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
      ],
      child: MaterialApp(theme: AppTheme.light, home: const AssistantScreen()),
    ),
  );
  await tester.pump();
}

http.Response _created(String prompt) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'data': {
        'request_id': 1,
        'user_id': 1,
        'prompt': prompt,
        'status': 'PROCESSING',
      },
    }),
  ),
  201,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('HU-10 — Mostrar campo de texto', () {
    testWidgets('CC1: muestra un campo de texto para introducir una solicitud', (
      tester,
    ) async {
      await _pumpAssistant(tester);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Escribe un plato o un producto…'), findsOneWidget);
    });

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
}
