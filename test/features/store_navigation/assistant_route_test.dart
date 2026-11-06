import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmarket/app/providers/store_providers.dart';
import 'package:smartmarket/app/smartmarket_app.dart';
import 'package:smartmarket/features/assistant/domain/entities/recipe_availability.dart';
import 'package:smartmarket/features/auth/data/auth_api.dart';
import 'package:smartmarket/features/auth/presentation/providers/auth_provider.dart';
import 'package:smartmarket/features/store_navigation/data/catalog_api.dart';
import 'package:smartmarket/features/store_navigation/data/motion_sensors.dart';
import 'package:smartmarket/features/store_navigation/data/repositories/preferences_product_names_repository.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/store_model.dart';
import 'package:smartmarket/features/store_navigation/domain/repositories/store_model_repository.dart';
import 'package:smartmarket/features/store_navigation/domain/services/yaw_tracker.dart';
import 'package:smartmarket/features/store_navigation/presentation/providers/store_model_provider.dart';
import 'package:smartmarket/features/store_navigation/presentation/widgets/route_summary_card.dart';
import 'package:smartmarket/features/store_navigation/presentation/widgets/supermarket_viewport.dart';

class _Controller extends AuthController {
  _Controller(this.session);

  final AuthSession session;

  @override
  Future<AuthSession?> build() async => session;
}

class _FakeSensors implements MotionSensors {
  final accelerationEvents = StreamController<MotionSample>.broadcast();
  final rotationEvents = StreamController<MotionSample>.broadcast();
  final magneticEvents = StreamController<MotionSample>.broadcast();

  @override
  Stream<MotionSample> get acceleration => accelerationEvents.stream;

  @override
  Stream<MotionSample> get rotation => rotationEvents.stream;

  @override
  Stream<MotionSample> get magnetic => magneticEvents.stream;

  /// Caminata de [seconds] a 1,8 pasos por segundo, mirando siempre al frente.
  void walk(double seconds) {
    final start = DateTime(2026);
    for (var i = 0; i < seconds * 50; i++) {
      final time = start.add(Duration(milliseconds: i * 20));
      final bounce = 2.5 * math.sin(2 * math.pi * 1.8 * i / 50);
      accelerationEvents.add(MotionSample(0, 0, 9.81 + bounce, time));
      rotationEvents.add(MotionSample(0, 0, 0, time));
    }
  }
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
      routeNodeIds: ['node_acceso', 'node_verduras'],
      productIds: ['PIL_0005'],
      routeNodes: [
        StoreRouteNode(
          id: 'node_acceso',
          x: 0,
          y: 0,
          z: 0,
          neighbors: ['node_verduras'],
        ),
        StoreRouteNode(
          id: 'node_verduras',
          x: 4,
          y: 0,
          z: 0,
          neighbors: ['node_acceso'],
        ),
      ],
      products: [
        StoreProduct(
          id: 'PIL_0005',
          name: 'Caja del modelo',
          routeNode: 'node_verduras',
          slotId: 'SLOT_1',
        ),
      ],
    ),
  );
}

/// Backend con el mismo producto en el espacio SLOT_1 de las dos sucursales.
Future<http.Response> _backend(http.Request request) async {
  final Object data = switch (request.url.path) {
    '/api/branches' => [
      {'branch_id': 1, 'model_3d_url': Supermarket.natural.assetPath},
      {'branch_id': 2, 'model_3d_url': Supermarket.piloto.assetPath},
    ],
    '/api/products/slots' => [
      {'code': 'SLOT_1', 'product_id': 20},
    ],
    _ => [
      {
        'product_id': 20,
        'sku': 'PIL_0005',
        'name': 'Tomate',
        'category_name': 'Verduras',
        'price': 5,
        'stock_quantity': 40,
      },
    ],
  };
  return http.Response(jsonEncode({'data': data}), 200);
}

const _route = ShoppingRoute(
  branchId: 2,
  branchName: 'SmartMarket Piloto',
  modelUrl: 'Modelos_3D/supermercado_2.glb',
  stops: [
    ShoppingRouteStop(
      itemId: 1,
      ingredientName: 'Tomate',
      productId: 20,
      productName: 'Tomate',
      isSubstitute: false,
    ),
  ],
  missing: ['Chorizo'],
);

const _user = AuthSession(token: 't', username: 'Ana', role: 'user');
const _admin = AuthSession(
  token: 't',
  username: 'Ana',
  role: 'admin',
  modelUrl: 'Modelos_3D/supermercado_1.glb',
);

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  AuthSession session = _user,
  MotionSensors? sensors,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _Controller(session)),
        motionSensorsProvider.overrideWithValue(sensors ?? _FakeSensors()),
        storeModelRepositoryProvider.overrideWithValue(_Repository()),
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
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

/// Avanza el reloj de la prueba y deja correr la E/S real del servidor del visor.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Retira la app para que el visor 3D cancele su temporizador de carga.
Future<void> _closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _sendRoute(WidgetTester tester, ProviderContainer container) async {
  container.read(mapRequestProvider.notifier).send(const ShowRouteRequest(_route));
  await _settle(tester);
}

double _walked(WidgetTester tester) =>
    tester
        .widget<SupermarketViewport>(find.byType(SupermarketViewport))
        .walkerPose
        ?.walked ??
    0;

void main() {
  group('Movimiento con los sensores', () {
    testWidgets('los pasos mueven al muñeco por la ruta', (tester) async {
      final sensors = _FakeSensors();
      final container = await _pumpApp(tester, sensors: sensors);
      await _sendRoute(tester, container);
      expect(_walked(tester), 0);

      sensors.walk(2);
      await _settle(tester);

      expect(_walked(tester), inInclusiveRange(1.4, 3.5));
      await _closeApp(tester);
    });

    testWidgets('el muñeco espera en la parada hasta confirmarla', (
      tester,
    ) async {
      final sensors = _FakeSensors();
      final container = await _pumpApp(tester, sensors: sensors);
      await _sendRoute(tester, container);

      sensors.walk(20);
      await _settle(tester);

      expect(_walked(tester), 4);
      expect(find.text('0 de 1 listos'), findsOneWidget);
      await _closeApp(tester);
    });

    testWidgets('confirmar una parada lejana ubica allí al muñeco', (
      tester,
    ) async {
      final container = await _pumpApp(tester);
      await _sendRoute(tester, container);

      await tester.tap(find.text('Ya lo tengo'));
      await _settle(tester);

      expect(_walked(tester), 4);
      await _closeApp(tester);
    });

    testWidgets('repetir la ruta vuelve el muñeco al inicio', (tester) async {
      final container = await _pumpApp(tester);
      await _sendRoute(tester, container);
      await tester.tap(find.text('Ya lo tengo'));
      await _settle(tester);

      await tester.tap(find.text('Repetir ruta'));
      await _settle(tester);

      expect(_walked(tester), 0);
      await _closeApp(tester);
    });

    testWidgets('los sensores solo corren con una ruta en curso', (
      tester,
    ) async {
      final sensors = _FakeSensors();
      final container = await _pumpApp(tester, sensors: sensors);
      expect(sensors.accelerationEvents.hasListener, isFalse);

      await _sendRoute(tester, container);
      expect(sensors.accelerationEvents.hasListener, isTrue);

      await tester.tap(find.text('Ya lo tengo'));
      await _settle(tester);
      expect(sensors.accelerationEvents.hasListener, isFalse);
      await _closeApp(tester);
    });

    testWidgets('sin acelerómetro avisa y los botones siguen funcionando', (
      tester,
    ) async {
      final sensors = _FakeSensors();
      final container = await _pumpApp(tester, sensors: sensors);
      await _sendRoute(tester, container);

      sensors.accelerationEvents.addError(StateError('NO_SENSOR'));
      // La cola de avisos empieza por el de los productos faltantes.
      await tester.pump(const Duration(seconds: 6));
      await _settle(tester);

      expect(
        find.text('Este teléfono no detecta pasos: avanza con "Ya lo tengo".'),
        findsOneWidget,
      );
      // El aviso cubre el botón mientras se muestra.
      await tester.pump(const Duration(seconds: 6));
      await _settle(tester);
      await tester.tap(find.text('Ya lo tengo'));
      await _settle(tester);
      expect(find.text('1 de 1 listos'), findsOneWidget);
      await _closeApp(tester);
    });

    testWidgets('al cargar la ruta el muñeco ya mira según la brújula', (
      tester,
    ) async {
      final sensors = _FakeSensors();
      final container = await _pumpApp(tester, sensors: sensors);
      await _sendRoute(tester, container);

      final time = DateTime(2026);
      sensors.accelerationEvents.add(MotionSample(0, 0, 9.81, time));
      sensors.magneticEvents.add(MotionSample(0, 30, -20, time));
      await _settle(tester);

      // Mirando al norte, aunque la ruta del mapa salga hacia +X.
      final notifier = container.read(navigationSessionProvider.notifier);
      expect(notifier.updateYaw(const YawReading(0, absolute: true))?.rotation, closeTo(math.pi, 1e-9));
      await _closeApp(tester);
    });

    testWidgets('repetir la ruta conserva la orientación real', (tester) async {
      final container = await _pumpApp(tester);
      await _sendRoute(tester, container);
      final notifier = container.read(navigationSessionProvider.notifier);
      notifier.updateYaw(const YawReading(0, absolute: true));

      notifier.restart();

      expect(container.read(navigationSessionProvider).pose?.rotation, closeTo(math.pi, 1e-9));
      await _closeApp(tester);
    });

    testWidgets('muestra los pasos detectados', (tester) async {
      final sensors = _FakeSensors();
      final container = await _pumpApp(tester, sensors: sensors);
      await _sendRoute(tester, container);
      expect(find.textContaining('0 pasos'), findsOneWidget);

      sensors.walk(2);
      await _settle(tester);

      expect(find.textContaining('0 pasos'), findsNothing);
      await _closeApp(tester);
    });

    testWidgets('el botón de la brújula alinea sin mover al muñeco', (
      tester,
    ) async {
      final container = await _pumpApp(tester);
      await _sendRoute(tester, container);

      await tester.tap(find.byTooltip('Alinear con la ruta'));
      await _settle(tester);

      expect(_walked(tester), 0);
      expect(find.text('0 de 1 listos'), findsOneWidget);
      await _closeApp(tester);
    });

    testWidgets('sin giroscopio ni brújula avanza con los pasos', (
      tester,
    ) async {
      final sensors = _FakeSensors();
      final container = await _pumpApp(tester, sensors: sensors);
      await _sendRoute(tester, container);

      sensors.rotationEvents.addError(StateError('NO_SENSOR'));
      sensors.magneticEvents.addError(StateError('NO_SENSOR'));
      await _settle(tester);
      final start = DateTime(2026);
      for (var i = 0; i < 100; i++) {
        final bounce = 2.5 * math.sin(2 * math.pi * 1.8 * i / 50);
        sensors.accelerationEvents.add(
          MotionSample(
            0,
            0,
            9.81 + bounce,
            start.add(Duration(milliseconds: i * 20)),
          ),
        );
      }
      await _settle(tester);

      expect(_walked(tester), greaterThan(0));
      await _closeApp(tester);
    });
  });

  testWidgets('la ruta del asistente cambia de supermercado y queda trazada', (
    tester,
  ) async {
    final container = await _pumpApp(tester);
    expect(container.read(selectedStoreProvider), Supermarket.natural);

    await _sendRoute(tester, container);

    expect(container.read(selectedStoreProvider), Supermarket.piloto);
    final viewport = tester.widget<SupermarketViewport>(
      find.byType(SupermarketViewport),
    );
    expect(viewport.routePlan?.products.map((p) => p.id), ['PIL_0005']);
    expect(find.text('Siguiente parada · 1 de 1'), findsOneWidget);
    expect(find.text('No hay en SmartMarket Piloto: Chorizo.'), findsOneWidget);
    await _closeApp(tester);
  });

  testWidgets('el resumen de la ruta no tapa los botones de la parada', (
    tester,
  ) async {
    final container = await _pumpApp(tester);
    await _sendRoute(tester, container);

    final summary = tester.getRect(find.byType(RouteSummaryCard));
    for (final label in ['Saltar', 'Ya lo tengo']) {
      final button = tester.getRect(find.text(label));
      expect(summary.overlaps(button), isFalse, reason: label);
    }

    await tester.tap(find.text('Ya lo tengo'));
    await _settle(tester);

    expect(find.text('1 de 1 listos'), findsOneWidget);
    await _closeApp(tester);
  });

  testWidgets('el botón de vista se reinicia al cambiar de supermercado', (
    tester,
  ) async {
    final container = await _pumpApp(tester);
    await tester.tap(find.byTooltip('Vista superior'));
    await _settle(tester);
    expect(find.byTooltip('Ver en 3D'), findsOneWidget);

    container
        .read(mapRequestProvider.notifier)
        .send(const SelectStoreRequest(Supermarket.piloto));
    await _settle(tester);

    expect(find.byTooltip('Vista superior'), findsOneWidget);
    await _closeApp(tester);
  });

  testWidgets('un admin con ruta puede seguirla parada a parada', (
    tester,
  ) async {
    final container = await _pumpApp(tester, session: _admin);

    container
        .read(mapRequestProvider.notifier)
        .send(
          const ShowRouteRequest(
            ShoppingRoute(
              branchId: 1,
              branchName: 'Supermercado Natural',
              modelUrl: 'Modelos_3D/supermercado_1.glb',
              stops: [
                ShoppingRouteStop(
                  itemId: 1,
                  ingredientName: 'Tomate',
                  productId: 20,
                  productName: 'Tomate',
                  isSubstitute: false,
                ),
              ],
            ),
          ),
        );
    await _settle(tester);

    expect(find.text('Ya lo tengo'), findsOneWidget);
    await _closeApp(tester);
  });

  testWidgets('un admin no pierde su mapa por una ruta de otra sucursal', (
    tester,
  ) async {
    final container = await _pumpApp(tester, session: _admin);
    final before = tester.state(find.byType(SupermarketViewport));

    await _sendRoute(tester, container);

    expect(tester.state(find.byType(SupermarketViewport)), same(before));
    expect(
      find.text('Tu cuenta solo puede ver Supermercado_1.'),
      findsOneWidget,
    );
    await _closeApp(tester);
  });
}
