import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmarket/app/providers/store_providers.dart';
import 'package:smartmarket/app/smartmarket_app.dart';
import 'package:smartmarket/core/widgets/sm_buttons.dart';
import 'package:smartmarket/features/auth/data/auth_api.dart';
import 'package:smartmarket/features/auth/presentation/providers/auth_provider.dart';
import 'package:smartmarket/features/store_navigation/data/catalog_api.dart';
import 'package:smartmarket/features/store_navigation/data/repositories/preferences_product_names_repository.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/store_model.dart';
import 'package:smartmarket/features/store_navigation/domain/repositories/store_model_repository.dart';
import 'package:smartmarket/features/store_navigation/presentation/screens/store_layout_screen.dart';
import 'package:smartmarket/features/store_navigation/presentation/widgets/supermarket_viewport.dart';

class _Controller extends AuthController {
  @override
  Future<AuthSession?> build() async => AuthSession(
    token: 't',
    username: 'Admin',
    role: 'admin',
    modelUrl: Supermarket.natural.assetPath,
  );
}

/// Dos pasillos: el 1 con el estante E1 (dos espacios) y el 2 con el E2 (uno).
class _Repository implements StoreModelRepository {
  int loads = 0;

  @override
  Future<StoreModel> load(Supermarket store) async {
    loads++;
    StoreProduct box(String id, String slot, String shelf, String node, double x) =>
        StoreProduct(
          id: id,
          name: 'Caja $id',
          routeNode: node,
          slotId: slot,
          shelfId: shelf,
          x: x,
          z: x / 2,
        );
    return StoreModel(
      store: store,
      bytes: Uint8List(0),
      metadata: StoreModelMetadata(
        byteLength: 0,
        triangles: 0,
        meshInstances: 0,
        materials: 0,
        routeNodeIds: const [],
        productIds: const [],
        products: [
          box('B1', 'SLOT_A1', 'E1', 'node_pasillo_01_01', 0),
          box('B2', 'SLOT_A2', 'E1', 'node_pasillo_01_02', 1),
          box('B3', 'SLOT_B1', 'E2', 'node_pasillo_02_01', 4),
        ],
      ),
    );
  }
}

final _writes = <(String, String, Object?)>[];

Future<http.Response> _backend(http.Request request) async {
  if (request.method != 'GET') {
    _writes.add((
      request.method,
      request.url.path,
      request.body.isEmpty ? null : jsonDecode(request.body),
    ));
    final created = request.method == 'POST' && request.url.path == '/api/products';
    return http.Response(jsonEncode({'data': {}}), created ? 201 : 200);
  }
  final Object data = switch (request.url.path) {
    '/api/branches' => [
      {'branch_id': 1, 'model_3d_url': Supermarket.natural.assetPath},
    ],
    '/api/products/slots' => [
      {'code': 'SLOT_A1', 'product_id': 10},
      {'code': 'SLOT_A2', 'product_id': 11},
      {'code': 'SLOT_B1', 'product_id': null},
    ],
    '/api/products/options' => {
      'categories': [
        {'category_id': 3, 'name': 'Despensa'},
      ],
      'sections': [],
    },
    _ => [
      for (final (id, name, stock) in [
        (10, 'Arroz', 40),
        (11, 'Fideo', 3),
        (12, 'Aceite', 8),
      ])
        {
          'product_id': id,
          'sku': 'SKU$id',
          'name': name,
          'category_name': 'Despensa',
          'price': 10,
          'stock_quantity': stock,
        },
    ],
  };
  return http.Response(jsonEncode({'data': data}), 200);
}

Future<_Repository> _pump(WidgetTester tester) async {
  _writes.clear();
  await tester.binding.setSurfaceSize(const Size(600, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repository = _Repository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_Controller.new),
        storeModelRepositoryProvider.overrideWithValue(repository),
        productNamesRepositoryProvider.overrideWithValue(
          MemoryProductNamesRepository(),
        ),
        catalogApiProvider.overrideWithValue(
          CatalogApi(
            client: MockClient(_backend),
            baseUri: Uri.parse('http://localhost:3000/api'),
            tokenReader: () async => 't',
          ),
        ),
      ],
      child: const SmartMarketApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

/// Compara las escrituras con [expected]; los cuerpos se comparan a fondo.
void _expectWrites(List<(String, String, Object?)> expected) {
  expect(_writes, hasLength(expected.length));
  for (final (index, (method, path, body)) in expected.indexed) {
    expect(_writes[index].$1, method);
    expect(_writes[index].$2, path);
    expect(_writes[index].$3, equals(body));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra los pasillos con nombre y lo que hay en cada estante', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(StoreLayoutScreen), findsOneWidget);
    expect(find.byType(SupermarketViewport), findsNothing);
    expect(find.text('Pasillo 1'), findsWidgets);
    expect(find.text('Pasillo 2'), findsOneWidget);
    expect(find.text('Estante E1'), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Fideo'), findsOneWidget);
    // Aceite está en el inventario, sin estante.
    expect(find.text('Inventario (1)'), findsOneWidget);
    expect(find.textContaining('3 espacios · 1 libre'), findsOneWidget);
  });

  testWidgets('intercambiar: se elige otro pasillo y su espacio', (
    tester,
  ) async {
    await _pump(tester);

    await _tap(tester, find.text('Arroz'));
    await _tap(tester, find.text('Intercambiar con otro producto'));
    expect(find.text('Intercambiando "Arroz"'), findsOneWidget);

    await _tap(tester, find.text('Pasillo 2'));
    await _tap(tester, find.text('Libre'));
    expect(find.text('Mover producto'), findsOneWidget);
    await _tap(tester, find.text('Mover'));

    _expectWrites([
      (
        'POST',
        '/api/products/slots/move',
        {'from_slot': 'SLOT_A1', 'to_slot': 'SLOT_B1'},
      ),
    ]);
    expect(find.text('Intercambiando "Arroz"'), findsNothing);
  });

  testWidgets('intercambiar con un producto de otro espacio pide confirmar', (
    tester,
  ) async {
    await _pump(tester);

    await _tap(tester, find.text('Arroz'));
    await _tap(tester, find.text('Intercambiar con otro producto'));
    await _tap(tester, find.text('Fideo'));

    expect(find.textContaining('cambiarán de lugar'), findsOneWidget);
    // Cancelar deja elegir otro destino.
    await _tap(tester, find.text('Cancelar').last);
    expect(_writes, isEmpty);
    expect(find.text('Intercambiando "Arroz"'), findsOneWidget);

    await _tap(tester, find.text('Fideo'));
    await _tap(tester, find.text('Confirmar'));
    expect(_writes.single.$3, {'from_slot': 'SLOT_A1', 'to_slot': 'SLOT_A2'});
  });

  testWidgets('reemplazar con un producto del inventario', (tester) async {
    await _pump(tester);

    await _tap(tester, find.text('Fideo'));
    await _tap(tester, find.text('Reemplazar con uno del inventario'));
    await _tap(tester, find.text('Aceite'));
    expect(find.textContaining('pasará al inventario'), findsOneWidget);
    await _tap(tester, find.text('Reemplazar'));

    _expectWrites([
      ('POST', '/api/products/slots/SLOT_A2/assign', {'product_id': 12}),
    ]);
  });

  testWidgets('desde Inventario se coloca un producto en un espacio libre', (
    tester,
  ) async {
    await _pump(tester);

    await _tap(tester, find.text('Inventario (1)'));
    await _tap(tester, find.text('Aceite'));
    expect(find.text('Colocando "Aceite"'), findsOneWidget);
    await _tap(tester, find.text('Pasillo 2'));
    await _tap(tester, find.text('Libre'));

    _expectWrites([
      ('POST', '/api/products/slots/SLOT_B1/assign', {'product_id': 12}),
    ]);
  });

  testWidgets('enviar al inventario libera el espacio', (tester) async {
    await _pump(tester);

    await _tap(tester, find.text('Arroz'));
    await _tap(tester, find.text('Enviar al inventario'));
    await _tap(tester, find.text('Enviar'));

    _expectWrites([
      ('DELETE', '/api/products/slots/SLOT_A1/product', null),
    ]);
  });

  testWidgets('crear un producto en un espacio libre', (tester) async {
    final repository = await _pump(tester);

    await _tap(tester, find.text('Pasillo 2'));
    await _tap(tester, find.text('Libre'));
    await _tap(tester, find.text('Crear un producto nuevo aquí'));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ej. Fideo canelón 400 g'),
      'Quinua',
    );
    await _tap(tester, find.text('Despensa'));
    await tester.enterText(
      find.widgetWithText(TextFormField, '0,00'),
      '12,5',
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Crear producto'));

    _expectWrites([
      (
        'POST',
        '/api/products',
        {
          'name': 'Quinua',
          'price': 12.5,
          'stock_quantity': 10.0,
          'category_id': 3,
          'unit_of_measure': 'unidad',
          'slot_code': 'SLOT_B1',
        },
      ),
    ]);
    // Al recargar los datos no se vuelve a leer el modelo 3D.
    expect(repository.loads, 1);
  });

  productsTabTests();
}

Future<void> _openProducts(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(NavigationDestination, 'Productos'));
  await tester.pumpAndSettle();
}

void productsTabTests() {
  testWidgets('Productos del admin: filtros por estado y por categoría', (
    tester,
  ) async {
    await _pump(tester);
    await _openProducts(tester);

    await _tap(tester, find.widgetWithText(PillChip, 'Despensa'));
    expect(find.text('Resultados'), findsOneWidget);
    expect(find.text('3 productos'), findsOneWidget);

    await _tap(tester, find.text('Sin estante (1)'));
    expect(find.text('Aceite'), findsOneWidget);
    expect(find.text('Arroz'), findsNothing);
    expect(find.text('Fideo'), findsNothing);

    // «Por agotarse» también es un indicador del resumen: se toca el chip.
    await _tap(tester, find.widgetWithText(PillChip, 'Por agotarse'));
    expect(find.text('Fideo'), findsOneWidget);
    expect(find.text('Arroz'), findsNothing);
    expect(find.text('1 producto'), findsOneWidget);
  });

  testWidgets('un producto sin estante lleva al plano para colocarlo', (
    tester,
  ) async {
    await _pump(tester);
    await _openProducts(tester);

    await _tap(tester, find.text('Sin estante (1)'));
    await _tap(tester, find.text('Aceite'));

    expect(find.byType(StoreLayoutScreen), findsOneWidget);
    expect(find.text('Colocando "Aceite"'), findsOneWidget);
  });

  testWidgets('crear producto desde Productos lo deja en el inventario', (
    tester,
  ) async {
    await _pump(tester);
    await _openProducts(tester);

    await _tap(tester, find.widgetWithText(FilledButton, 'Crear producto'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ej. Fideo canelón 400 g'),
      'Té verde',
    );
    await _tap(tester, find.text('Despensa'));
    await tester.enterText(find.widgetWithText(TextFormField, '0,00'), '8');
    await _tap(tester, find.text('caja'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Crear producto'));

    _expectWrites([
      (
        'POST',
        '/api/products',
        {
          'name': 'Té verde',
          'price': 8.0,
          'stock_quantity': 10.0,
          'category_id': 3,
          'unit_of_measure': 'caja',
        },
      ),
    ]);
    expect(find.textContaining('quedó en el inventario'), findsOneWidget);
  });
}
