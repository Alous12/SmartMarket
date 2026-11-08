import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmarket/features/store_navigation/data/datasources/glb_metadata_reader.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/floor_plan.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/store_model.dart';
import 'package:smartmarket/features/store_navigation/domain/services/route_guidance.dart';
import 'package:smartmarket/features/store_navigation/domain/services/store_route_planner.dart';
import 'package:smartmarket/features/store_navigation/domain/services/yaw_tracker.dart';
import 'package:smartmarket/features/store_navigation/presentation/providers/store_model_provider.dart';

/// Nodo en el piso (x, z). Los vecinos se declaran en un solo sentido.
StoreRouteNode _node(
  String id,
  double x,
  double z, [
  List<String> neighbors = const [],
]) => StoreRouteNode(id: id, x: x, y: 0, z: z, neighbors: neighbors);

StoreProduct _product(String id, String node, {double? x, double? z}) =>
    StoreProduct(id: id, name: id, routeNode: node, x: x, z: z);

/// Giros de más de 25 grados en un recorrido.
int _turns(List<StoreRouteNode> path) {
  var turns = 0;
  for (var i = 2; i < path.length; i++) {
    final x1 = path[i - 1].x - path[i - 2].x,
        z1 = path[i - 1].z - path[i - 2].z;
    final x2 = path[i].x - path[i - 1].x, z2 = path[i].z - path[i - 1].z;
    final norm = math.sqrt(x1 * x1 + z1 * z1) * math.sqrt(x2 * x2 + z2 * z2);
    if (norm < 1e-9) continue;
    final cosine = ((x1 * x2 + z1 * z2) / norm).clamp(-1.0, 1.0);
    if (math.acos(cosine) > 25 * math.pi / 180) turns++;
  }
  return turns;
}

/// Plano con todas las celdas libres salvo [blocked] (columna, fila).
FloorPlan _plan({
  required int columns,
  required int rows,
  Set<(int, int)> blocked = const {},
}) {
  final free = Uint8List(columns * rows)..fillRange(0, columns * rows, 1);
  for (final (column, row) in blocked) {
    free[row * columns + column] = 0;
  }
  return FloorPlan(
    minX: -1,
    minZ: -1,
    cellSize: 1,
    columns: columns,
    rows: rows,
    free: free,
  );
}

void main() {
  group('Castigo por giros', () {
    test('entre dos caminos igual de largos elige el de menos vueltas', () {
      // De (0,0) a (3,3): en escalera o en L miden lo mismo.
      final nodes = <StoreRouteNode>[];
      for (var x = 0; x <= 3; x++) {
        for (var z = 0; z <= 3; z++) {
          nodes.add(
            _node('n${x}_$z', x.toDouble(), z.toDouble(), [
              if (x < 3) 'n${x + 1}_$z',
              if (z < 3) 'n${x}_${z + 1}',
            ]),
          );
        }
      }
      final route = const StoreRoutePlanner().plan(
        routeNodes: nodes,
        products: [_product('p', 'n3_3')],
        startNodeId: 'n0_0',
        productIds: ['p'],
      );

      expect(route.distance, closeTo(6, 1e-9));
      expect(_turns(route.path), 1);
    });

    test('sin castigo el resultado mide lo mismo que antes', () {
      final nodes = [
        _node('a', 0, 0, ['b', 'c']),
        _node('b', 5, 0, ['d']),
        _node('c', 0, 5, ['d']),
        _node('d', 5, 5),
      ];
      final route = const StoreRoutePlanner(turnPenalty: 0, uTurnPenalty: 0)
          .plan(
            routeNodes: nodes,
            products: [_product('p', 'd')],
            startNodeId: 'a',
            productIds: ['p'],
          );
      expect(route.distance, closeTo(10, 1e-9));
    });

    // Tras recoger en s hay que ir a t. Volver por a y b (14 m) es más corto
    // que seguir de frente y rodear por x = 11 (16 m), pero obliga a dar media
    // vuelta en s.
    final loop = [
      _node('inicio', 0, 0, ['a']),
      _node('a', 5, 0, ['s', 'b']),
      _node('s', 10, 0, ['esquina']),
      _node('esquina', 11, 0, ['esquina2']),
      _node('esquina2', 11, 4, ['t']),
      _node('b', 5, 4, ['t']),
      _node('t', 0, 4),
    ];
    final products = [_product('ps', 's'), _product('pt', 't')];

    test('recuerda por dónde llegó a una parada y evita la media vuelta', () {
      final route = const StoreRoutePlanner().plan(
        routeNodes: loop,
        products: products,
        startNodeId: 'inicio',
        productIds: ['ps', 'pt'],
      );

      expect(route.stopNodeIds, ['s', 't']);
      expect(route.nodeIds, ['inicio', 'a', 's', 'esquina', 'esquina2', 't']);
    });

    test('sin castigo vuelve por donde vino, como el cálculo anterior', () {
      final route = const StoreRoutePlanner(turnPenalty: 0, uTurnPenalty: 0)
          .plan(
            routeNodes: loop,
            products: products,
            startNodeId: 'inicio',
            productIds: ['ps', 'pt'],
          );

      expect(route.nodeIds, ['inicio', 'a', 's', 'a', 'b', 't']);
    });
  });

  group('Seguir la ruta sí o sí', () {
    // Al este 4 m y luego al sur 4 m; hay un pasillo libre hacia el norte.
    final nodes = [
      _node('inicio', 0, 0, ['esquina', 'norte']),
      _node('esquina', 4, 0, ['fin']),
      _node('fin', 4, 4),
      _node('norte', 0, -10),
    ];
    final plan = const StoreRoutePlanner().plan(
      routeNodes: nodes,
      products: [_product('p', 'fin')],
      startNodeId: 'inicio',
      productIds: ['p'],
    );

    test('aunque el teléfono mire a otro lado, avanza por la línea', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationSessionProvider.notifier);
      notifier.start(plan);
      const north = YawReading(0, absolute: true);

      for (var i = 0; i < 4; i++) {
        notifier.registerSteps(1, north);
      }
      var pose = container.read(navigationSessionProvider).pose!;
      expect(pose.walked, closeTo(2.8, 1e-9));
      expect(pose.x, closeTo(2.8, 1e-9));
      expect(pose.z, closeTo(0, 1e-9));

      for (var i = 0; i < 4; i++) {
        notifier.registerSteps(1, north);
      }
      pose = container.read(navigationSessionProvider).pose!;
      // Dobla en la esquina como la ruta, sin cortar camino.
      expect(pose.x, closeTo(4, 1e-9));
      expect(pose.z, closeTo(1.6, 1e-9));
    });

    test('se detiene en la parada hasta confirmarla', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationSessionProvider.notifier);
      notifier.start(plan);
      for (var i = 0; i < 30; i++) {
        notifier.registerSteps(1, const YawReading(0, absolute: true));
      }
      final pose = container.read(navigationSessionProvider).pose!;
      expect(pose.walked, closeTo(8, 1e-9));
      expect(pose.x, closeTo(4, 1e-9));
      expect(pose.z, closeTo(4, 1e-9));
    });

    test('el muñeco mira hacia donde mira el teléfono', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(navigationSessionProvider.notifier);
      notifier.start(plan);
      notifier.registerSteps(1, const YawReading(math.pi, absolute: true));
      // Mirando al sur: rotación 0 (hacia +Z).
      expect(
        container.read(navigationSessionProvider).pose!.rotation,
        closeTo(0, 1e-9),
      );
    });
  });

  group('Línea recta en zonas abiertas', () {
    // Escalera de (0,0) a (4,4) por una zona abierta.
    final nodes = [
      _node('a', 0, 0, ['b']),
      _node('b', 1, 0, ['c']),
      _node('c', 1, 1, ['d']),
      _node('d', 2, 1, ['e']),
      _node('e', 2, 2, ['f']),
      _node('f', 3, 2, ['g']),
      _node('g', 3, 3, ['h']),
      _node('h', 4, 3, ['i']),
      _node('i', 4, 4),
    ];
    final products = [_product('p', 'i')];

    test('sin obstáculos une el inicio y la parada con una recta', () {
      final route = const StoreRoutePlanner().plan(
        routeNodes: nodes,
        products: products,
        startNodeId: 'a',
        productIds: ['p'],
        floorPlan: _plan(columns: 7, rows: 7),
      );

      expect(route.nodeIds, ['a', 'i']);
      expect(route.distance, closeTo(math.sqrt(32), 1e-9));
    });

    test('un mueble en medio obliga a rodearlo', () {
      // Celda (3,3) = punto (2.5, 2.5): la diagonal pasa por ahí.
      final route = const StoreRoutePlanner().plan(
        routeNodes: nodes,
        products: products,
        startNodeId: 'a',
        productIds: ['p'],
        floorPlan: _plan(columns: 7, rows: 7, blocked: {(3, 3)}),
      );

      expect(route.nodeIds.first, 'a');
      expect(route.nodeIds.last, 'i');
      expect(route.nodeIds.length, greaterThan(2));
      final plan = _plan(columns: 7, rows: 7, blocked: {(3, 3)});
      for (var i = 1; i < route.path.length; i++) {
        final a = route.path[i - 1], b = route.path[i];
        expect(plan.isClear(a.x, a.z, b.x, b.z), isTrue);
      }
    });

    test('sin plano sigue los pasillos del grafo', () {
      final route = const StoreRoutePlanner().plan(
        routeNodes: nodes,
        products: products,
        startNodeId: 'a',
        productIds: ['p'],
      );
      expect(route.nodeIds.length, nodes.length);
    });

    test('las paradas nunca se saltan al enderezar', () {
      final route = const StoreRoutePlanner().plan(
        routeNodes: nodes,
        products: [_product('mitad', 'e'), ...products],
        startNodeId: 'a',
        productIds: ['mitad', 'p'],
        floorPlan: _plan(columns: 7, rows: 7),
      );
      expect(route.nodeIds, ['a', 'e', 'i']);
      expect(route.productDistances.first, closeTo(math.sqrt(8), 1e-9));
    });
  });

  group('Indicaciones paso a paso', () {
    // Hacia el este 10 m y luego hacia el sur (abajo del mapa) 5 m.
    final path = [_node('a', 0, 0), _node('b', 10, 0), _node('c', 10, 5)];

    test('ir al este y doblar hacia el sur es girar a la derecha', () {
      final guidance = RouteGuidance(path);
      expect(guidance.turns.single.kind, TurnKind.right);
      expect(guidance.turns.single.at, closeTo(10, 1e-9));

      final next = guidance.next(walked: 3, target: 15);
      expect(next.arriving, isFalse);
      expect(next.kind, TurnKind.right);
      expect(next.distance, closeTo(7, 1e-9));
    });

    test('ir al este y doblar hacia el norte es girar a la izquierda', () {
      final guidance = RouteGuidance([
        _node('a', 0, 0),
        _node('b', 10, 0),
        _node('c', 10, -5),
      ]);
      expect(guidance.turns.single.kind, TurnKind.left);
    });

    test('volver por el mismo pasillo es dar media vuelta', () {
      final guidance = RouteGuidance([
        _node('a', 0, 0),
        _node('b', 10, 0),
        _node('c', 2, 0),
      ]);
      expect(guidance.turns.single.kind, TurnKind.uTurn);
      // Recién confirmada la parada en b, lo próximo es dar la vuelta.
      expect(guidance.next(walked: 10, target: 18).kind, TurnKind.uTurn);
    });

    test('dice a qué lado del pasillo está el producto', () {
      final guidance = RouteGuidance(path);
      final south = _product('s', 'b', x: 6, z: 1.5);
      final north = _product('n', 'b', x: 6, z: -1.5);

      final right = guidance.next(walked: 0, target: 6, product: south);
      expect(right.arriving, isTrue);
      expect(right.distance, closeTo(6, 1e-9));
      expect(right.side, ProductSide.right);
      expect(
        guidance.next(walked: 0, target: 6, product: north).side,
        ProductSide.left,
      );
      expect(guidance.next(walked: 0, target: 6).side, isNull);
    });

    test('una diagonal que dobla una esquina cuenta como un solo giro', () {
      final guidance = RouteGuidance([
        _node('a', 0, 0),
        _node('b', 10, 0),
        _node('c', 10.7, 0.7),
        _node('d', 10.7, 8),
      ]);
      expect(guidance.turns.single.kind, TurnKind.right);
    });
  });

  group('Recoger lo que está de paso', () {
    // Pasillo sin salida: entrada -> fideos -> azúcar. Harina queda en otro lado.
    final nodes = [
      _node('entrada', 0, 0, ['cruce']),
      _node('cruce', 0, -2, ['fideos', 'harina']),
      _node('fideos', 0, -6, ['azucar']),
      _node('azucar', 0, -8),
      _node('harina', 6, -2),
    ];
    final products = [
      _product('F', 'fideos'),
      _product('A', 'azucar'),
      _product('H', 'harina'),
    ];

    test('si el camino pasa por un producto, se recoge ahí', () {
      for (final order in [
        ['A', 'F', 'H'],
        ['F', 'A', 'H'],
        ['H', 'A', 'F'],
      ]) {
        final route = const StoreRoutePlanner().plan(
          routeNodes: nodes,
          products: products,
          startNodeId: 'entrada',
          productIds: order,
        );
        final azucar = route.stopNodeIds.indexOf('azucar');
        expect(route.stopNodeIds.indexOf('fideos'), lessThan(azucar));
        for (var i = 1; i < route.productDistances.length; i++) {
          expect(
            route.productDistances[i],
            greaterThan(route.productDistances[i - 1]),
          );
        }
      }
    });

    test('la ruta termina en el último producto, sin tramo extra', () {
      final route = const StoreRoutePlanner().plan(
        routeNodes: nodes,
        products: products,
        startNodeId: 'entrada',
        productIds: ['F', 'A'],
      );
      expect(route.nodeIds, ['entrada', 'cruce', 'fideos', 'azucar']);
      expect(route.distance, closeTo(8, 1e-9));
    });
  });

  group('Modelos reales', () {
    for (final (file, start) in [
      ('Modelos_3D/supermercado_1.glb', 'node_acceso'),
      ('Modelos_3D/supermercado_2.glb', 'node_entrada'),
    ]) {
      final metadata = readGlbMetadata(File(file).readAsBytesSync());

      test('$file: todo el grafo se alcanza desde la entrada', () {
        final byId = {for (final node in metadata.routeNodes) node.id: node};
        final neighbors = <String, Set<String>>{
          for (final node in metadata.routeNodes) node.id: {},
        };
        for (final node in metadata.routeNodes) {
          for (final id in node.neighbors) {
            expect(byId, contains(id), reason: '${node.id} -> $id');
            neighbors[node.id]!.add(id);
            neighbors[id]!.add(node.id);
          }
        }
        final seen = <String>{};
        final pending = [start];
        while (pending.isNotEmpty) {
          final id = pending.removeLast();
          if (seen.add(id)) pending.addAll(neighbors[id]!);
        }
        expect(byId.keys.toSet().difference(seen), isEmpty);
      });

      test('$file: tiene plano del piso y posición de los productos', () {
        final plan = metadata.floorPlan;
        expect(plan, isNotNull);
        expect(plan!.free.where((cell) => cell == 1).length, greaterThan(1000));
        expect(
          metadata.products.every((p) => p.x != null && p.z != null),
          isTrue,
        );
        // La entrada y las cajas están en zonas caminables.
        final entrance = metadata.routeNodes.firstWhere((n) => n.id == start);
        expect(plan.isFree(entrance.x, entrance.z), isTrue);
      });

      test(
        '$file: la ruta termina en el último producto y no atraviesa muebles',
        () {
          final products = metadata.products
              .where((p) => p.routeNode.isNotEmpty)
              .toList();
          final random = math.Random(11);
          for (var trial = 0; trial < 15; trial++) {
            final ids = <String>{};
            while (ids.length < 6) {
              ids.add(products[random.nextInt(products.length)].id);
            }
            final route = const StoreRoutePlanner().plan(
              routeNodes: metadata.routeNodes,
              products: metadata.products,
              startNodeId: start,
              productIds: ids.toList(),
              floorPlan: metadata.floorPlan,
            );
            expect(route.nodeIds.first, start);
            // Termina en el último producto: no lleva a la caja.
            expect(route.nodeIds.last, route.stopNodeIds.last);
            expect(route.productDistances.last, closeTo(route.distance, 1e-9));
            expect(route.products.map((p) => p.id).toSet(), ids);
            expect(
              route.productDistances.last,
              lessThanOrEqualTo(route.distance),
            );
            // Las paradas aparecen en la ruta en el orden en que se visitan.
            var from = 0;
            for (final stop in route.stopNodeIds) {
              final at = route.nodeIds.indexOf(stop, from);
              expect(at, greaterThanOrEqualTo(from), reason: stop);
              from = at;
            }
            // Cada tramo es un pasillo del grafo o una recta sin muebles.
            final byId = {for (final n in metadata.routeNodes) n.id: n};
            for (var i = 1; i < route.path.length; i++) {
              final a = route.path[i - 1], b = route.path[i];
              final adjacent =
                  byId[a.id]!.neighbors.contains(b.id) ||
                  byId[b.id]!.neighbors.contains(a.id);
              expect(
                adjacent || metadata.floorPlan!.isClear(a.x, a.z, b.x, b.z),
                isTrue,
                reason: '${a.id} -> ${b.id}',
              );
            }
          }
        },
      );
    }

    for (final (file, start) in [
      ('Modelos_3D/supermercado_1.glb', 'node_acceso'),
      ('Modelos_3D/supermercado_2.glb', 'node_entrada'),
    ]) {
      test('$file: un recorrido completo nunca termina antes de tiempo', () {
        final metadata = readGlbMetadata(File(file).readAsBytesSync());
        final products = metadata.products
            .where((p) => p.routeNode.isNotEmpty)
            .toList();
        final random = math.Random(5);
        for (var trial = 0; trial < 150; trial++) {
          final ids = <String>{};
          final size = 1 + random.nextInt(14);
          while (ids.length < size) {
            ids.add(products[random.nextInt(products.length)].id);
          }
          final plan = const StoreRoutePlanner().plan(
            routeNodes: metadata.routeNodes,
            products: metadata.products,
            startNodeId: start,
            productIds: ids.toList(),
            floorPlan: metadata.floorPlan,
          );
          final reason = 'lista $trial: ${ids.join(', ')}';
          expect(plan.products.map((p) => p.id).toSet(), ids, reason: reason);
          expect(
            plan.distance,
            closeTo(plan.productDistances.last, 1e-9),
            reason: reason,
          );
          final byId = {for (final n in metadata.routeNodes) n.id: n};
          // Ningún producto queda atrás: la ruta no pasa por uno antes de su parada.
          var walked = 0.0;
          final firstPass = <String, double>{plan.nodeIds.first: 0};
          for (var i = 1; i < plan.path.length; i++) {
            walked += plan.path[i - 1].distanceTo(plan.path[i]);
            firstPass.putIfAbsent(plan.nodeIds[i], () => walked);
          }
          for (var i = 0; i < plan.products.length; i++) {
            expect(
              firstPass[plan.products[i].routeNode],
              closeTo(plan.productDistances[i], 1e-6),
              reason: '$reason, parada ${plan.products[i].id}',
            );
          }

          final container = ProviderContainer();
          final notifier = container.read(navigationSessionProvider.notifier);
          notifier.start(plan);
          for (var stop = 0; stop < plan.products.length; stop++) {
            // Camina hasta la parada; se detiene en ella aunque siga caminando.
            for (var step = 0; step < 2000; step++) {
              notifier.registerSteps(1, null);
            }
            final session = container.read(navigationSessionProvider);
            expect(session.current, plan.products[stop], reason: reason);
            expect(
              session.pose!.walked,
              closeTo(plan.productDistances[stop], 1e-6),
              reason: reason,
            );
            final node = byId[plan.products[stop].routeNode]!;
            expect(session.pose!.x, closeTo(node.x, 1e-6), reason: reason);
            expect(session.pose!.z, closeTo(node.z, 1e-6), reason: reason);
            notifier.advance(collected: true);
          }
          final done = container.read(navigationSessionProvider);
          expect(done.current, isNull, reason: reason);
          expect(done.collected, plan.products.length, reason: reason);
          container.dispose();
        }
      });
    }

    test(
      'Supermercado_1: se cruza entre pasillos solo donde no hay góndola',
      () {
        final metadata = readGlbMetadata(
          File('Modelos_3D/supermercado_1.glb').readAsBytesSync(),
        );
        List<String> neighbors(String id) =>
            metadata.routeNodes.firstWhere((node) => node.id == id).neighbors;
        // La fila 3 es el corte a mitad de las góndolas.
        expect(neighbors('node_pasillo_01_03'), contains('node_pasillo_02_03'));
        expect(neighbors('node_pasillo_03_03'), contains('node_pasillo_04_03'));
        // Las filas 2 y 4 tienen el estante en medio.
        expect(
          neighbors('node_pasillo_01_02'),
          isNot(contains('node_pasillo_02_02')),
        );
        expect(
          neighbors('node_pasillo_01_04'),
          isNot(contains('node_pasillo_02_04')),
        );
      },
    );

    test('Supermercado_1: sigue recto por el corte en vez de retroceder', () {
      final metadata = readGlbMetadata(
        File('Modelos_3D/supermercado_1.glb').readAsBytesSync(),
      );
      // Fideos y Azúcar en el pasillo 1; Harina al otro lado de la misma góndola.
      final route = const StoreRoutePlanner().plan(
        routeNodes: metadata.routeNodes,
        products: metadata.products,
        startNodeId: 'node_acceso',
        productIds: ['GRP_0004', 'PRD_0015', 'GRP_0005'],
        floorPlan: metadata.floorPlan,
      );
      expect(
        route.nodeIds.sublist(route.nodeIds.indexOf('node_pasillo_01_02')),
        [
          'node_pasillo_01_02',
          'node_pasillo_01_03',
          'node_pasillo_02_03',
          'node_pasillo_02_02',
        ],
      );
    });

    test('Supermercado_1: el pago solo se alcanza por su propio carril', () {
      final metadata = readGlbMetadata(
        File('Modelos_3D/supermercado_1.glb').readAsBytesSync(),
      );
      final pago = metadata.routeNodes.firstWhere(
        (node) => node.id == 'node_caja_02_pago',
      );
      expect(pago.neighbors.toSet(), {
        'node_caja_02_fila',
        'node_caja_02_salida',
      });
    });
  });
}
