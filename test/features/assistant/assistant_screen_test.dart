import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmarket/core/theme/app_theme.dart';
import 'package:smartmarket/features/assistant/data/assistant_api.dart';
import 'package:smartmarket/features/assistant/domain/entities/recipe_availability.dart';
import 'package:smartmarket/features/assistant/presentation/providers/assistant_providers.dart';
import 'package:smartmarket/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:smartmarket/features/auth/data/auth_api.dart';
import 'package:smartmarket/features/auth/presentation/providers/auth_provider.dart';

class _SignedInController extends AuthController {
  @override
  Future<AuthSession?> build() async =>
      const AuthSession(token: 'signed-token', username: 'Ana', role: 'user');

  @override
  Future<void> logout() async => state = const AsyncData(null);
}

Future<void> _pumpAssistant(
  WidgetTester tester, {
  MockClientHandler? handler,
  Widget home = const AssistantScreen(),
  Future<int?> Function()? branchId,
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
        assistantBranchIdProvider.overrideWith(
          (ref) => branchId?.call() ?? Future.value(2),
        ),
        assistantPollIntervalProvider.overrideWithValue(Duration.zero),
      ],
      child: MaterialApp(theme: AppTheme.light, home: home),
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

const _noStock = <String, Object?>{
  'branch_id': 2,
  'branch_name': 'SmartMarket Piloto',
  'items': <Object?>[],
  'routes': <Object?>[],
};

/// Responde el envío y luego cada consulta con el siguiente estado de [states].
MockClientHandler _assistant(
  List<Map<String, Object?>> states, {
  List<Map<String, dynamic>>? sentBodies,
  Map<String, Object?>? availability = _noStock,
}) {
  var polls = 0;
  return (request) async {
    if (request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      sentBodies?.add(body);
      return _created(body['prompt'] as String);
    }
    if (request.url.path.endsWith('/availability')) {
      return availability == null
          ? http.Response('{"error":"Falló"}', 500)
          : _json(availability, 200);
    }
    if (request.url.path == '/api/assistant/requests') {
      return http.Response.bytes(
        utf8.encode(jsonEncode({'data': _history})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
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
      'item_id': 1,
      'ingredient_id': 48,
      'name': 'Masa para lasaña',
      'quantity': 250,
      'unit': 'g',
    },
    {
      'item_id': 2,
      'ingredient_id': 26,
      'name': 'Carne molida',
      'quantity': 0.5,
      'unit': 'kg',
    },
    {
      'item_id': 3,
      'ingredient_id': 42,
      'name': 'Sal',
      'quantity': null,
      'unit': null,
    },
  ],
};

const _history = [
  {
    'request_id': 1,
    'recipe_name': 'Lasaña de carne',
    'branch_id': 1,
    'ingredient_count': 3,
    'created_at': '2026-11-02T12:00:00.000Z',
  },
];

Map<String, Object?> _product(String name) => {
  'name': name,
  'section_name': 'Zona fria',
};

Map<String, Object?> _item(
  int id,
  String name,
  String availability, {
  bool elsewhere = false,
  List<Map<String, Object?>> substitutes = const [],
}) => {
  'item_id': id,
  'name': name,
  'availability': availability,
  'available_products': const <Object?>[],
  'other_branches': [
    if (elsewhere) {'branch_name': 'Otro', 'products': const <Object?>[]},
  ],
  'substitutes': substitutes,
};

Map<String, Object?> _substitute(String branch, String product) => {
  'branch_name': branch,
  'ingredient_name': product,
  'products': [_product(product)],
};

Map<String, Object?> _stop(
  int itemId,
  String product, {
  bool similar = false,
}) => {
  'item_id': itemId,
  'ingredient_name': 'Ingrediente $itemId',
  'product_id': itemId * 10,
  'product_name': product,
  'is_substitute': similar,
};

Map<String, Object?> _route(
  int branchId,
  String name,
  List<Map<String, Object?>> stops, {
  List<String> missing = const [],
}) => {
  'branch_id': branchId,
  'branch_name': name,
  'model_3d_url': 'Modelos_3D/supermercado_$branchId.glb',
  'stops': stops,
  'missing': missing,
};

final _threeItems = [
  _item(1, 'Masa para lasaña', 'AVAILABLE', elsewhere: true),
  _item(2, 'Carne molida', 'AVAILABLE', elsewhere: true),
  _item(3, 'Sal', 'AVAILABLE', elsewhere: true),
];

final _allStops = [_stop(1, 'Lasagna'), _stop(2, 'Res'), _stop(3, 'Sal')];

/// La lista completa solo en el supermercado abierto (Piloto, id 2).
final _onlyHere = <String, Object?>{
  'branch_id': 2,
  'items': _threeItems,
  'routes': [_route(2, 'Piloto', _allStops)],
};

/// La lista completa en los dos supermercados.
final _inBoth = <String, Object?>{
  'branch_id': 2,
  'items': _threeItems,
  'routes': [_route(2, 'Piloto', _allStops), _route(1, 'Natural', _allStops)],
};

/// La sal no existe: tiene reemplazo en ambos; la carne no tiene ninguno.
final _withMissing = <String, Object?>{
  'branch_id': 2,
  'items': [
    _item(1, 'Masa para lasaña', 'AVAILABLE'),
    _item(2, 'Carne molida', 'UNAVAILABLE'),
    _item(
      3,
      'Sal',
      'UNAVAILABLE',
      substitutes: [
        _substitute('Piloto', 'Sal marina'),
        _substitute('Natural', 'Sal rosada'),
      ],
    ),
  ],
  'routes': [
    _route(
      2,
      'Piloto',
      [_stop(1, 'Lasagna'), _stop(3, 'Sal marina', similar: true)],
      missing: ['Carne molida'],
    ),
  ],
};

Future<void> _askLasagna(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'lasaña');
  await tester.tap(find.byTooltip('Enviar'));
  await tester.pumpAndSettle();
}

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

    testWidgets('vuelve a consultar la sucursal si la primera vez falló', (
      tester,
    ) async {
      final sent = <Map<String, dynamic>>[];
      var queries = 0;
      await _pumpAssistant(
        tester,
        handler: _assistant([_lasagna], sentBodies: sent),
        branchId: () async => ++queries == 1 ? null : 2,
      );

      await tester.enterText(find.byType(TextField), 'lasaña');
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pumpAndSettle();

      expect(sent.single['branch_id'], 2);
    });

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
    testWidgets('permite recuperar el seguimiento si falla la conexión', (
      tester,
    ) async {
      var polls = 0;
      await _pumpAssistant(
        tester,
        handler: (request) async {
          if (request.url.path.endsWith('/models')) {
            return http.Response(jsonEncode({'data': []}), 200);
          }
          if (request.method == 'POST') return _created('lasaña');
          if (request.url.path.endsWith('/availability')) {
            return _json(_noStock, 200);
          }
          if (++polls <= 5) {
            return http.Response('{"error":"sin conexión"}', 500);
          }
          return _json({'request_id': 1, 'prompt': 'lasaña', ..._lasagna}, 200);
        },
      );
      await tester.enterText(find.byType(TextField), 'lasaña');
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('La petición podría seguir procesándose'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Lasaña de carne'), findsOneWidget);
    });

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
        await tester.tap(find.text('Ingredientes (3)'));
        await tester.pumpAndSettle();
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

  group('HU-18, HU-20 y HU-21 — Disponibilidad y ruta de compra', () {
    testWidgets('con todo en este supermercado resume en vez de listar', (
      tester,
    ) async {
      await _pumpAssistant(
        tester,
        handler: _assistant([_lasagna], availability: _onlyHere),
      );

      await _askLasagna(tester);

      expect(
        find.text('Existen todos los productos en este supermercado.'),
        findsOneWidget,
      );
      expect(find.text('Mostrar ruta'), findsOneWidget);
      expect(find.text('Masa para lasaña'), findsNothing);
    });

    testWidgets('con todo en los dos permite elegir supermercado', (
      tester,
    ) async {
      ShoppingRoute? shown;
      await _pumpAssistant(
        tester,
        handler: _assistant([_lasagna], availability: _inBoth),
        home: _Host(onRoute: (route) => shown = route),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await _askLasagna(tester);

      expect(find.textContaining('en ambos supermercados'), findsOneWidget);
      expect(find.text('Mostrar ruta'), findsNothing);
      await tester.ensureVisible(find.text('Natural'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Natural'));
      await tester.pumpAndSettle();

      expect(find.byType(AssistantScreen), findsNothing);
      expect(shown?.modelUrl, 'Modelos_3D/supermercado_1.glb');
    });

    testWidgets(
      'avisa lo que no existe con sus reemplazos en cada supermercado',
      (tester) async {
        await _pumpAssistant(
          tester,
          handler: _assistant([_lasagna], availability: _withMissing),
        );

        await _askLasagna(tester);

        expect(find.text('No hay en ningún supermercado'), findsOneWidget);
        expect(find.text('Sal'), findsOneWidget);
        expect(find.text('Reemplazo: Sal marina en Piloto'), findsOneWidget);
        expect(find.text('Reemplazo: Sal rosada en Natural'), findsOneWidget);
        expect(find.text('Carne molida'), findsOneWidget);
        expect(find.text('Sin reemplazo disponible'), findsOneWidget);
        expect(find.text('Masa para lasaña'), findsNothing);
      },
    );

    testWidgets('Mostrar ruta cierra el asistente y entrega la ruta', (
      tester,
    ) async {
      ShoppingRoute? shown;
      await _pumpAssistant(
        tester,
        handler: _assistant([_lasagna], availability: _withMissing),
        home: _Host(onRoute: (route) => shown = route),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await _askLasagna(tester);
      await tester.ensureVisible(find.text('Mostrar ruta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mostrar ruta'));
      await tester.pumpAndSettle();

      expect(find.byType(AssistantScreen), findsNothing);
      expect(shown?.modelUrl, 'Modelos_3D/supermercado_2.glb');
      expect(shown?.stops.map((stop) => stop.productId), [10, 30]);
      expect(shown?.missing, ['Carne molida']);
    });

    testWidgets('sin productos en ningún supermercado no ofrece la ruta', (
      tester,
    ) async {
      await _pumpAssistant(tester, handler: _assistant([_lasagna]));

      await _askLasagna(tester);

      expect(find.text('Mostrar ruta'), findsNothing);
      expect(
        find.text('Ningún supermercado tiene estos ingredientes.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'si falla el inventario conserva la receta y permite reintentar',
      (tester) async {
        await _pumpAssistant(
          tester,
          handler: _assistant([_lasagna], availability: null),
        );

        await _askLasagna(tester);

        expect(find.text('Lasaña de carne'), findsOneWidget);
        expect(
          find.text('No se pudo consultar el inventario.'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);
      },
    );
  });

  group('Chat de la sesión', () {
    testWidgets('el chat se conserva al salir y volver', (tester) async {
      await _pumpAssistant(
        tester,
        handler: _assistant([_lasagna], availability: _onlyHere),
        home: _Host(onRoute: (_) {}),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await _askLasagna(tester);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantScreen), findsNothing);

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('x'), findsOneWidget);
      expect(find.text('Lasaña de carne'), findsOneWidget);
      expect(find.text('Mostrar ruta'), findsOneWidget);
    });

    testWidgets('una petición en curso termina aunque se salga del chat', (
      tester,
    ) async {
      await _pumpAssistant(
        tester,
        handler: _assistant([
          {'status': 'PROCESSING'},
          _lasagna,
        ], availability: _onlyHere),
        home: _Host(onRoute: (_) {}),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'lasaña');
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Lasaña de carne'), findsOneWidget);
      expect(find.text('Mostrar ruta'), findsOneWidget);
    });

    testWidgets('el chat se borra al cerrar la sesión', (tester) async {
      await _pumpAssistant(
        tester,
        handler: _assistant([_lasagna], availability: _onlyHere),
      );
      await _askLasagna(tester);
      expect(find.text('Lasaña de carne'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AssistantScreen)),
      );
      await container.read(authControllerProvider.notifier).logout();
      await tester.pumpAndSettle();

      expect(find.text('Lasaña de carne'), findsNothing);
      expect(find.text('¿Qué quieres cocinar hoy?'), findsOneWidget);
    });

    testWidgets('una sugerencia llena el campo sin enviar nada', (
      tester,
    ) async {
      await _pumpAssistant(tester);

      await tester.tap(find.text('Quiero preparar arroz con leche'));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Quiero preparar arroz con leche',
      );
    });
  });

  group('Historial de recetas', () {
    /// Falla si alguien intenta consultar a la IA con un POST.
    MockClientHandler withoutAi(Map<String, Object?> availability) {
      final handler = _assistant([_lasagna], availability: availability);
      return (request) async {
        expect(request.method, 'GET');
        return handler(request);
      };
    }

    Future<void> repeatLasagna(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Historial de recetas'));
      await tester.pumpAndSettle();
      expect(find.text('Lasaña de carne'), findsOneWidget);
      expect(find.text('3 ingredientes · 02/11/2026'), findsOneWidget);
      await tester.tap(find.text('Repetir ruta'));
      await tester.pumpAndSettle();
    }

    testWidgets('repite la ruta sin consultar a la IA', (tester) async {
      ShoppingRoute? shown;
      await _pumpAssistant(
        tester,
        handler: withoutAi(_onlyHere),
        home: _Host(onRoute: (route) => shown = route),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await repeatLasagna(tester);

      expect(find.byType(AssistantScreen), findsNothing);
      expect(shown?.branchName, 'Piloto');
    });

    testWidgets(
      'si hay dos supermercados deja la receta en el chat para elegir',
      (tester) async {
        await _pumpAssistant(tester, handler: withoutAi(_inBoth));

        await repeatLasagna(tester);

        expect(find.byType(AssistantScreen), findsOneWidget);
        expect(find.text('Natural'), findsOneWidget);
        expect(find.text('Piloto'), findsOneWidget);
      },
    );
  });
}

/// Pantalla anterior al asistente, para comprobar lo que devuelve al cerrarse.
class _Host extends StatelessWidget {
  const _Host({required this.onRoute});

  final ValueChanged<ShoppingRoute> onRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextButton(
        onPressed: () async {
          final route = await Navigator.of(context).push<ShoppingRoute>(
            MaterialPageRoute(builder: (_) => const AssistantScreen()),
          );
          if (route != null) onRoute(route);
        },
        child: const Text('Abrir'),
      ),
    );
  }
}
