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
import 'package:smartmarket/features/store_navigation/presentation/widgets/store_segments.dart';
import 'package:smartmarket/features/store_navigation/presentation/widgets/supermarket_viewport.dart';

class _Controller extends AuthController {
  _Controller(this.session);

  final AuthSession session;

  @override
  Future<AuthSession?> build() async => session;
}

class _Repository implements StoreModelRepository {
  final requested = <Supermarket>[];

  @override
  Future<StoreModel> load(Supermarket store) async {
    requested.add(store);
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
          StoreProduct(id: 'p1', name: 'Leche de ${store.shortTitle}'),
        ],
      ),
    );
  }
}

const _user = AuthSession(token: 't', username: 'Ana', role: 'user');

Future<_Repository> _pumpApp(
  WidgetTester tester, {
  AuthSession session = _user,
}) async {
  final repository = _Repository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _Controller(session)),
        storeModelRepositoryProvider.overrideWithValue(repository),
        productNamesRepositoryProvider.overrideWithValue(
          MemoryProductNamesRepository(),
        ),
        catalogApiProvider.overrideWithValue(
          CatalogApi(
            client: MockClient((request) async => http.Response('{}', 500)),
            baseUri: Uri.parse('http://localhost:3000/api'),
            tokenReader: () async => 't',
          ),
        ),
      ],
      child: const SmartMarketApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
  return repository;
}

/// Retira la app para que el visor 3D cancele su temporizador de carga.
Future<void> _closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NavigationDestination, label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('la barra muestra las tres pestañas y abre Supermercados', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.byType(NavigationDestination), findsNWidgets(3));
    for (final label in ['Asistente', 'Productos', 'Supermercados']) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
    expect(find.text(Supermarket.natural.title), findsOneWidget);
    await _closeApp(tester);
  });

  testWidgets('el asistente como pestaña no ofrece Volver', (tester) async {
    await _pumpApp(tester);

    await _openTab(tester, 'Asistente');

    expect(find.text('Asistente SmartMarket'), findsOneWidget);
    expect(find.byTooltip('Volver'), findsNothing);
    await _closeApp(tester);
  });

  testWidgets('tocar un producto lleva al mapa sin recargarlo', (tester) async {
    final repository = await _pumpApp(tester);

    await _openTab(tester, 'Productos');
    await tester.tap(find.text('Leche de Mini_Market'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
    expect(find.text('Leche de Mini_Market'), findsNothing);
    expect(repository.requested, [Supermarket.natural]);
    await _closeApp(tester);
  });

  testWidgets('el usuario cambia de sucursal desde Productos', (tester) async {
    final repository = await _pumpApp(tester);

    await _openTab(tester, 'Productos');
    await tester.tap(find.text(Supermarket.piloto.shortTitle));
    await tester.pump();
    // El mapa cierra el servidor local de su visor con E/S real antes de cambiar.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leche de SuperMarket'), findsOneWidget);
    expect(repository.requested, [Supermarket.natural, Supermarket.piloto]);
    await _closeApp(tester);
  });

  testWidgets('el admin solo ve su sucursal, sin selector', (tester) async {
    await _pumpApp(
      tester,
      session: AuthSession(
        token: 't',
        username: 'Admin',
        role: 'admin',
        modelUrl: Supermarket.piloto.assetPath,
      ),
    );

    expect(find.byType(StoreSegments), findsNothing);
    await _openTab(tester, 'Productos');

    expect(find.byType(StoreSegments), findsNothing);
    expect(find.text('Leche de SuperMarket'), findsOneWidget);
    await _closeApp(tester);
  });

  testWidgets('el teclado mueve el chat, pero no cambia el tamaño del mapa', (
    tester,
  ) async {
    await _pumpApp(tester);
    final map = find.byType(SupermarketViewport, skipOffstage: false);
    final mapSize = tester.getSize(map);
    await _openTab(tester, 'Asistente');
    final height = tester.getSize(find.byType(MaterialApp)).height;

    const keyboard = 300.0;
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    expect(tester.getSize(map), mapSize);
    final field = tester.getBottomLeft(find.byType(TextField));
    // El campo queda justo encima del teclado, con su margen de 16.
    expect(field.dy, closeTo(height - keyboard - 16, 1));
    await _closeApp(tester);
  });

  testWidgets('no se suma dos veces el margen inferior del sistema', (
    tester,
  ) async {
    const systemBar = 24.0;
    tester.view.padding = FakeViewPadding(
      bottom: systemBar * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);
    await _pumpApp(tester);
    await _openTab(tester, 'Asistente');

    final barTop = tester.getTopLeft(find.byType(NavigationBar)).dy;
    final field = tester.getBottomLeft(find.byType(TextField));
    expect(field.dy, closeTo(barTop - 16, 1));
    await _closeApp(tester);
  });

  testWidgets('Atrás en otra pestaña vuelve a Supermercados sin salir', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _openTab(tester, 'Productos');
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
    expect(find.text('¿Salir de SmartMarket?'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('¿Salir de SmartMarket?'), findsOneWidget);
    await _closeApp(tester);
  });
}
