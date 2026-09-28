import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartmarket/features/store_navigation/data/datasources/glb_metadata_reader.dart';

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

  test('El supermercado real respeta el presupuesto y conserva sus IDs', () {
    final bytes = File('Modelos_3D/supermercado_1.glb').readAsBytesSync();
    final metadata = readGlbMetadata(bytes);
    expect(metadata.triangles, inInclusiveRange(1, 80000));
    expect(metadata.routeNodeIds, contains('node_acceso'));
    expect(metadata.productIds, contains('ARROZ_001'));
    expect(metadata.productIds.length, 135);
    expect(metadata.routeNodeIds.length, 59);
    final arroz = metadata.products.firstWhere((p) => p.id == 'ARROZ_001');
    expect(arroz.name, 'Arroz-Perlita');
  });

  test('El supermercado piloto tiene cajas, productos editables y nodos', () {
    final bytes = File('Modelos_3D/supermercado_2.glb').readAsBytesSync();
    final metadata = readGlbMetadata(bytes);
    expect(metadata.triangles, inInclusiveRange(1, 80000));
    expect(metadata.productIds.length, 247);
    expect(metadata.products.length, 247);
    expect(metadata.routeNodeIds, contains('node_entrada'));
    expect(metadata.routeNodeIds.length, 276);
    final first = metadata.products.firstWhere((p) => p.id == 'PIL_0001');
    expect(first.name, isNotEmpty);
    expect(first.category, 'Frutas');
    expect(first.routeNode, startsWith('node_'));
  });
}
