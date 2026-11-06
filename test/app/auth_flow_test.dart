import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmarket/app/providers/store_providers.dart';
import 'package:smartmarket/app/smartmarket_app.dart';
import 'package:smartmarket/features/auth/data/auth_api.dart';
import 'package:smartmarket/features/auth/presentation/providers/auth_provider.dart';
import 'package:smartmarket/features/store_navigation/data/catalog_api.dart';
import 'package:smartmarket/features/store_navigation/data/repositories/preferences_product_names_repository.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/store_model.dart';
import 'package:smartmarket/features/store_navigation/domain/repositories/store_model_repository.dart';
import 'package:smartmarket/features/users/data/user_api.dart';
import 'package:smartmarket/features/users/presentation/providers/users_providers.dart';

class _MemoryTokenStorage implements AuthTokenStorage {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> delete() async => token = null;
}

class _Repository implements StoreModelRepository {
  @override
  Future<StoreModel> load(Supermarket store) async => StoreModel(
    store: store,
    bytes: Uint8List(0),
    metadata: const StoreModelMetadata(
      byteLength: 0,
      triangles: 0,
      meshInstances: 0,
      materials: 0,
      routeNodeIds: [],
      productIds: [],
    ),
  );
}

http.Response _error(String message, int status) => http.Response.bytes(
  utf8.encode(jsonEncode({'error': message})),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> _pumpApp(WidgetTester tester, MockClientHandler handler) async {
  final client = MockClient(handler);
  final baseUri = Uri.parse('http://localhost:3000/api');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authApiProvider.overrideWithValue(
          AuthApi(
            client: client,
            baseUri: baseUri,
            tokenStorage: _MemoryTokenStorage(),
          ),
        ),
        userApiProvider.overrideWithValue(
          UserApi(client: client, baseUri: baseUri),
        ),
        storeModelRepositoryProvider.overrideWithValue(_Repository()),
        productNamesRepositoryProvider.overrideWithValue(
          MemoryProductNamesRepository(),
        ),
        catalogApiProvider.overrideWithValue(
          CatalogApi(
            client: client,
            baseUri: baseUri,
            tokenReader: () async => 't',
          ),
        ),
      ],
      child: const SmartMarketApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

String _text(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(_field(label)).controller!.text;

Future<void> _submitLogin(WidgetTester tester) async {
  await tester.enterText(_field('Correo electrónico'), 'ana@correo.com');
  await tester.enterText(_field('Contraseña'), 'clave-incorrecta');
  await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
  await tester.pumpAndSettle();
}

Future<void> _openRegister(WidgetTester tester) async {
  await tester.ensureVisible(find.text('¿No tienes cuenta? Regístrate'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
  await tester.pumpAndSettle();
}

Future<void> _submitRegister(WidgetTester tester) async {
  await tester.enterText(_field('Nombre'), 'Ana');
  await tester.enterText(_field('Apellido'), 'Rojas');
  await tester.enterText(_field('Correo electrónico'), 'ana@correo.com');
  await tester.enterText(_field('Contraseña'), 'clave-segura');
  await tester.enterText(_field('Confirmar contraseña'), 'clave-segura');
  final button = find.widgetWithText(FilledButton, 'Crear cuenta');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('un login fallido muestra el error y conserva el correo', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      (request) async => _error('Correo o contraseña incorrectos.', 401),
    );

    await _submitLogin(tester);

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(_text(tester, 'Correo electrónico'), 'ana@correo.com');
  });

  testWidgets('un registro fallido se queda en el registro con sus datos', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      (request) async => _error('El correo electrónico ya está registrado.', 409),
    );
    await _openRegister(tester);

    await _submitRegister(tester);

    expect(find.text('Regístrate para empezar a explorar SmartMarket.'), findsOne);
    expect(
      find.text('El correo electrónico ya está registrado.'),
      findsOneWidget,
    );
    expect(_text(tester, 'Nombre'), 'Ana');
  });

  testWidgets('el error del login no aparece en el registro', (tester) async {
    await _pumpApp(
      tester,
      (request) async => _error('Correo o contraseña incorrectos.', 401),
    );
    await _submitLogin(tester);

    await _openRegister(tester);

    expect(find.text('Correo o contraseña incorrectos.'), findsNothing);
  });

  testWidgets('un login correcto abre el mapa y cerrar sesión vuelve al login', (
    tester,
  ) async {
    await _pumpApp(tester, (request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({
            'data': {'token': 't', 'username': 'Ana', 'role': 'user'},
          }),
          200,
        );
      }
      return _error('No disponible', 500);
    });

    await _submitLogin(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Inicia sesión para explorar el supermercado.'), findsOne);
  });
}
