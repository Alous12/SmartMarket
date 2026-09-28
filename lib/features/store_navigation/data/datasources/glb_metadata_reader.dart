import 'dart:convert';
import 'dart:typed_data';

import '../../domain/entities/store_model.dart';

/// Counts the active scene, including repeated mesh instances and glTF extras.
StoreModelMetadata readGlbMetadata(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (bytes.length < 20 ||
      data.getUint32(0, Endian.little) != 0x46546C67 ||
      data.getUint32(4, Endian.little) != 2 ||
      data.getUint32(8, Endian.little) != bytes.length ||
      data.getUint32(16, Endian.little) != 0x4E4F534A) {
    throw const FormatException('El archivo no es un GLB 2.0 válido.');
  }
  final jsonLength = data.getUint32(12, Endian.little);
  if (20 + jsonLength > bytes.length) {
    throw const FormatException('El GLB está incompleto.');
  }
  final json =
      jsonDecode(utf8.decode(bytes.sublist(20, 20 + jsonLength)))
          as Map<String, dynamic>;
  final nodes = (json['nodes'] as List?) ?? [];
  final meshes = (json['meshes'] as List?) ?? [];
  final accessors = (json['accessors'] as List?) ?? [];
  final scenes = (json['scenes'] as List?) ?? [];
  if (scenes.isEmpty) {
    throw const FormatException('El GLB no contiene una escena.');
  }
  final activeNodes = <int>{};
  void visit(int index) {
    if (index < 0 || index >= nodes.length) {
      throw const FormatException('El GLB referencia un nodo inexistente.');
    }
    if (!activeNodes.add(index)) return;
    for (final child in (nodes[index]['children'] as List?) ?? []) {
      visit(child as int);
    }
  }

  for (final index in scenes[(json['scene'] as int?) ?? 0]['nodes'] as List) {
    visit(index as int);
  }
  var triangles = 0;
  var instances = 0;
  final routeIds = <String>{};
  final productIds = <String>{};
  for (final index in activeNodes) {
    final node = nodes[index] as Map<String, dynamic>;
    final extras = (node['extras'] as Map?) ?? {};
    if (extras['kind'] == 'route_node') {
      routeIds.add((extras['node_id'] ?? node['name']) as String);
    }
    if (extras['kind'] == 'product_group' && extras['product_id'] is String) {
      productIds.add(extras['product_id'] as String);
    }
    if (node['mesh'] == null) continue;
    instances++;
    for (final primitive in meshes[node['mesh']]['primitives'] as List) {
      if ((primitive['mode'] ?? 4) != 4) continue;
      final accessor =
          primitive['indices'] ?? primitive['attributes']['POSITION'];
      triangles += (accessors[accessor]['count'] as int) ~/ 3;
    }
  }
  return StoreModelMetadata(
    byteLength: bytes.length,
    triangles: triangles,
    meshInstances: instances,
    materials: ((json['materials'] as List?) ?? []).length,
    routeNodeIds: List.unmodifiable(routeIds),
    productIds: List.unmodifiable(productIds),
  );
}
