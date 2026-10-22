import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartmarket/features/store_navigation/data/datasources/glb_metadata_reader.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/store_model.dart';
import 'package:smartmarket/features/store_navigation/domain/services/store_route_planner.dart';

Uint8List _glb(Map<String, Object> json) {
  final payload = utf8.encode(jsonEncode(json));
  final padded = (payload.length + 3) & ~3;
  final bytes = Uint8List(20 + padded);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, 0x46546C67, Endian.little);
  data.setUint32(4, 2, Endian.little);
  data.setUint32(8, bytes.length, Endian.little);
  data.setUint32(12, padded, Endian.little);
  data.setUint32(16, 0x4E4F534A, Endian.little);
  bytes.fillRange(20, bytes.length, 32);
  bytes.setRange(20, 20 + payload.length, payload);
  return bytes;
}

void main() {
  test('Cuenta las instancias de la escena activa, sin sumar otra escena', () {
    final metadata = readGlbMetadata(
      _glb({
        'scene': 1,
        'scenes': [
          {
            'nodes': [0],
          },
          {
            'nodes': [1, 2],
          },
        ],
        'nodes': [
          {'mesh': 0},
          {
            'mesh': 0,
            'children': [3],
          },
          {'mesh': 0},
          {
            'name': 'node_acceso',
            'extras': {'kind': 'route_node', 'node_id': 'entrada'},
          },
        ],
        'meshes': [
          {
            'primitives': [
              {
                'indices': 0,
                'attributes': {'POSITION': 1},
              },
            ],
          },
        ],
        'accessors': [
          {'count': 36},
          {'count': 24},
        ],
      }),
    );
    expect(metadata.triangles, 24);
    expect(metadata.meshInstances, 2);
    expect(metadata.routeNodeIds, ['entrada']);
  });

  test('Rechaza archivos inválidos e incompletos', () {
    expect(() => readGlbMetadata(Uint8List(8)), throwsFormatException);
    final bytes = _glb({
      'scenes': [
        {'nodes': <int>[]},
      ],
    });
    expect(
      () => readGlbMetadata(bytes.sublist(0, bytes.length - 4)),
      throwsFormatException,
    );
  });

  test('Lee posiciones globales y vecinos de los nodos de ruta', () {
    final metadata = readGlbMetadata(
      _glb({
        'scenes': [
          {
            'nodes': [0],
          },
        ],
        'nodes': [
          {
            'translation': [10, 0, 0],
            'children': [1, 2],
          },
          {
            'translation': [2, 0, 0],
            'extras': {
              'kind': 'route_node',
              'node_id': 'entrada',
              'vecinos': ['pasillo'],
            },
          },
          {
            'translation': [-2, 0, 0],
            'extras': {
              'kind': 'route_node',
              'node_id': 'pasillo',
              'vecinos': 'entrada',
            },
          },
        ],
      }),
    );
    final entry = metadata.routeNodes.firstWhere(
      (node) => node.id == 'entrada',
    );
    final aisle = metadata.routeNodes.firstWhere(
      (node) => node.id == 'pasillo',
    );
    expect(entry.x, 12);
    expect(aisle.x, 8);
    expect(entry.neighbors, ['pasillo']);
    expect(aisle.neighbors, ['entrada']);
  });

  test('El respaldo conecta pasillos sin atravesar las góndolas', () {
    final metadata = readGlbMetadata(
      _glb({
        'scenes': [
          {
            'nodes': [0, 1, 2, 3, 4, 5],
          },
        ],
        'nodes': [
          {
            'translation': [0, 0, 0],
            'extras': {'kind': 'route_node', 'node_id': 'node_pasillo_01_01'},
          },
          {
            'translation': [0, 0, 7],
            'extras': {'kind': 'route_node', 'node_id': 'node_pasillo_01_02'},
          },
          {
            'translation': [0, 0, 14],
            'extras': {'kind': 'route_node', 'node_id': 'node_pasillo_01_03'},
          },
          {
            'translation': [7, 0, 0],
            'extras': {'kind': 'route_node', 'node_id': 'node_pasillo_02_01'},
          },
          {
            'translation': [7, 0, 7],
            'extras': {'kind': 'route_node', 'node_id': 'node_pasillo_02_02'},
          },
          {
            'translation': [7, 0, 14],
            'extras': {'kind': 'route_node', 'node_id': 'node_pasillo_02_03'},
          },
        ],
      }),
    );

    expect(
      metadata.routeNodes
          .firstWhere((node) => node.id == 'node_pasillo_01_02')
          .neighbors,
      containsAll(['node_pasillo_01_01', 'node_pasillo_01_03']),
    );
    expect(
      metadata.routeNodes
          .firstWhere((node) => node.id == 'node_pasillo_01_02')
          .neighbors,
      isNot(contains('node_pasillo_02_02')),
    );
    expect(
      metadata.routeNodes
          .firstWhere((node) => node.id == 'node_pasillo_01_01')
          .neighbors,
      contains('node_pasillo_02_01'),
    );
  });

  test('Calcula la ruta con A* y ordena óptimamente las paradas mock', () {
    final nodes = <StoreRouteNode>[
      const StoreRouteNode(
        id: 'entrada',
        x: 0,
        y: 0,
        z: 0,
        neighbors: ['este', 'norte', 'oeste'],
      ),
      const StoreRouteNode(
        id: 'este',
        x: 4,
        y: 0,
        z: 0,
        neighbors: ['entrada', 'norte', 'oeste'],
      ),
      const StoreRouteNode(
        id: 'norte',
        x: 0,
        y: 3,
        z: 0,
        neighbors: ['entrada', 'este', 'oeste'],
      ),
      const StoreRouteNode(
        id: 'oeste',
        x: -4,
        y: 0,
        z: 0,
        neighbors: ['entrada', 'este', 'norte'],
      ),
    ];
    final products = <StoreProduct>[
      const StoreProduct(id: 'p1', name: 'Queso', routeNode: 'este'),
      const StoreProduct(id: 'p2', name: 'Tomate', routeNode: 'norte'),
      const StoreProduct(id: 'p3', name: 'Harina', routeNode: 'oeste'),
    ];

    final route = const StoreRoutePlanner().plan(
      routeNodes: nodes,
      products: products,
      startNodeId: 'entrada',
      productIds: ['p1', 'p2', 'p3'],
    );

    expect(route.nodeIds.first, 'entrada');
    expect(route.stopNodeIds.toSet(), {'este', 'norte', 'oeste'});
    expect(route.products.length, 3);
    expect(route.distance, closeTo(14, 1e-9));
  });

  test('El supermercado real respeta el presupuesto y conserva sus IDs', () {
    final bytes = File('Modelos_3D/supermercado_1.glb').readAsBytesSync();
    final metadata = readGlbMetadata(bytes);
    expect(metadata.triangles, inInclusiveRange(1, 80000));
    expect(metadata.routeNodeIds, contains('node_acceso'));
    expect(metadata.productIds, contains('ARROZ_001'));
    expect(metadata.productIds.length, 147);
    expect(metadata.productIds, contains('IMP_001'));
    expect(metadata.routeNodeIds.length, 59);
    expect(metadata.routeNodes.length, metadata.routeNodeIds.length);
    expect(metadata.routeNodes.any((node) => node.neighbors.isNotEmpty), isTrue);
    expect(
      metadata.routeNodes.firstWhere((node) => node.id == 'node_acceso').neighbors,
      isNotEmpty,
    );
    final arroz = metadata.products.firstWhere((p) => p.id == 'ARROZ_001');
    expect(arroz.name, 'Arroz-Perlita');
    expect(
      metadata.routeNodeIds,
      contains(arroz.routeNode),
    );
    final route = const StoreRoutePlanner().plan(
      routeNodes: metadata.routeNodes,
      products: metadata.products,
      startNodeId: 'node_acceso',
      productIds: [arroz.id],
    );
    expect(route.nodeIds.first, 'node_acceso');
    expect(route.nodeIds.last, arroz.routeNode);
  });

  test('El supermercado piloto tiene cajas, productos editables y nodos', () {
    final bytes = File('Modelos_3D/supermercado_2.glb').readAsBytesSync();
    final metadata = readGlbMetadata(bytes);
    expect(metadata.triangles, inInclusiveRange(1, 80000));
    expect(metadata.productIds.length, 247);
    expect(metadata.products.length, 247);
    expect(metadata.routeNodeIds, contains('node_entrada'));
    expect(metadata.routeNodeIds.length, 276);
    expect(metadata.routeNodes.length, metadata.routeNodeIds.length);
    expect(metadata.routeNodes.any((node) => node.neighbors.isNotEmpty), isTrue);
    final first = metadata.products.firstWhere((p) => p.id == 'PIL_0001');
    expect(first.name, isNotEmpty);
    expect(first.category, 'Frutas');
    expect(first.routeNode, startsWith('node_'));
  });
}
