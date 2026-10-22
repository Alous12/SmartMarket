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
  final parents = <int, int>{};
  void visit(int index, [int? parent]) {
    if (index < 0 || index >= nodes.length) {
      throw const FormatException('El GLB referencia un nodo inexistente.');
    }
    if (parent != null) parents.putIfAbsent(index, () => parent);
    if (!activeNodes.add(index)) return;
    for (final child in (nodes[index]['children'] as List?) ?? []) {
      visit(child as int, index);
    }
  }

  for (final index in scenes[(json['scene'] as int?) ?? 0]['nodes'] as List) {
    visit(index as int);
  }
  final worldMatrices = <int, List<double>>{};
  List<double> worldMatrix(int index) {
    final cached = worldMatrices[index];
    if (cached != null) return cached;
    final local = _localMatrix(nodes[index] as Map<String, dynamic>);
    final parent = parents[index];
    final matrix = parent == null
        ? local
        : _multiplyMatrices(worldMatrix(parent), local);
    worldMatrices[index] = matrix;
    return matrix;
  }
  var triangles = 0;
  var instances = 0;
  final routeIds = <String>{};
  final routeNodes = <String, StoreRouteNode>{};
  final productIds = <String>{};
  final products = <String, StoreProduct>{};
  for (final index in activeNodes) {
    final node = nodes[index] as Map<String, dynamic>;
    final extras = (node['extras'] as Map?) ?? {};
    if (extras['kind'] == 'route_node') {
      final id = (extras['node_id'] ?? node['name']) as String;
      routeIds.add(id);
      final matrix = worldMatrix(index);
      routeNodes.putIfAbsent(
        id,
        () => StoreRouteNode(
          id: id,
          x: matrix[12],
          y: matrix[13],
          z: matrix[14],
          neighbors: List.unmodifiable(_readNeighbors(extras['vecinos'])),
        ),
      );
    }
    if (extras['kind'] == 'product_group' && extras['product_id'] is String) {
      final id = extras['product_id'] as String;
      productIds.add(id);
      products.putIfAbsent(
        id,
        () => StoreProduct(
          id: id,
          name: (extras['display_name'] ?? id).toString(),
          category: (extras['category'] ?? '').toString(),
          routeNode: (extras['route_node'] ?? '').toString(),
        ),
      );
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
  final resolvedRouteNodes = routeNodes.values.every(
    (node) => node.neighbors.isEmpty,
  )
      ? _buildAisleFallbackGraph(routeNodes.values)
      : routeNodes.values.toList(growable: false);
  return StoreModelMetadata(
    byteLength: bytes.length,
    triangles: triangles,
    meshInstances: instances,
    materials: ((json['materials'] as List?) ?? []).length,
    routeNodeIds: List.unmodifiable(routeIds),
    routeNodes: List.unmodifiable(resolvedRouteNodes),
    productIds: List.unmodifiable(productIds),
    products: List.unmodifiable(products.values),
  );
}

/// The Natural model predates route metadata. Its `node_pasillo_CC_RR` nodes
/// describe a grid of longitudinal aisles (CC) and their ordered positions
/// (RR). Shelves lie between aisles, so only the first and last row form
/// transverse corridors. Connecting all nearby points would cut through them.
List<StoreRouteNode> _buildAisleFallbackGraph(Iterable<StoreRouteNode> nodes) {
  final routeNodes = nodes.toList(growable: false);
  final aislePattern = RegExp(r'^node_pasillo_(\d+)_(\d+)$');
  final aisles = <int, List<_AisleNode>>{};
  final adjacency = <String, Set<String>>{
    for (final node in routeNodes) node.id: <String>{},
  };

  void connect(String first, String second) {
    if (first == second) return;
    adjacency[first]!.add(second);
    adjacency[second]!.add(first);
  }

  for (final node in routeNodes) {
    final match = aislePattern.firstMatch(node.id);
    if (match == null) continue;
    final aisle = int.parse(match.group(1)!);
    final row = int.parse(match.group(2)!);
    aisles.putIfAbsent(aisle, () => []).add(_AisleNode(node, row));
  }

  for (final nodesInAisle in aisles.values) {
    nodesInAisle.sort((a, b) => a.row.compareTo(b.row));
    for (var index = 1; index < nodesInAisle.length; index++) {
      connect(nodesInAisle[index - 1].node.id, nodesInAisle[index].node.id);
    }
  }

  final orderedAisles = aisles.keys.toList()..sort();
  for (final row in <int>[
    for (final aisle in orderedAisles) ...[
      aisles[aisle]!.map((entry) => entry.row).reduce((a, b) => a < b ? a : b),
      aisles[aisle]!.map((entry) => entry.row).reduce((a, b) => a > b ? a : b),
    ],
  ].toSet()) {
    final across = <StoreRouteNode>[];
    for (final aisle in orderedAisles) {
      final entry = aisles[aisle]!.where((node) => node.row == row).firstOrNull;
      if (entry != null) across.add(entry.node);
    }
    for (var index = 1; index < across.length; index++) {
      connect(across[index - 1].id, across[index].id);
    }
  }

  final specialNodes = routeNodes.where(
    (node) => aislePattern.firstMatch(node.id) == null,
  );
  for (final node in specialNodes) {
    final closest = routeNodes
        .where((candidate) => candidate.id != node.id)
        .toList()
      ..sort((a, b) => node.distanceTo(a).compareTo(node.distanceTo(b)));
    for (final candidate in closest.take(2)) {
      // Special nodes sit in the vestibule, checkouts or at aisle endpoints.
      // This limit reaches their local access without creating long shortcuts.
      if (node.distanceTo(candidate) <= 9) connect(node.id, candidate.id);
    }
  }

  return [
    for (final node in routeNodes)
      StoreRouteNode(
        id: node.id,
        x: node.x,
        y: node.y,
        z: node.z,
        neighbors: List.unmodifiable(adjacency[node.id]!),
      ),
  ];
}

class _AisleNode {
  const _AisleNode(this.node, this.row);

  final StoreRouteNode node;
  final int row;
}

List<String> _readNeighbors(Object? value) {
  if (value is List) {
    return value
        .map((neighbor) => neighbor.toString().trim())
        .where((neighbor) => neighbor.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(',')
        .map((neighbor) => neighbor.trim())
        .where((neighbor) => neighbor.isNotEmpty)
        .toList();
  }
  return const [];
}

List<double> _localMatrix(Map<String, dynamic> node) {
  final matrix = node['matrix'];
  if (matrix is List && matrix.length == 16) {
    return matrix.map((value) => (value as num).toDouble()).toList();
  }

  final translation = _vector3(node['translation'], const [0, 0, 0]);
  final rotation = node['rotation'] is List
      ? (node['rotation'] as List)
            .map((value) => (value as num).toDouble())
            .toList()
      : const [0.0, 0.0, 0.0, 1.0];
  final scale = _vector3(node['scale'], const [1, 1, 1]);
  final x = rotation[0];
  final y = rotation[1];
  final z = rotation[2];
  final w = rotation[3];
  final x2 = x * x;
  final y2 = y * y;
  final z2 = z * z;
  final xy = x * y;
  final xz = x * z;
  final yz = y * z;
  final xw = x * w;
  final yw = y * w;
  final zw = z * w;
  return [
    (1 - 2 * (y2 + z2)) * scale[0],
    (2 * (xy + zw)) * scale[0],
    (2 * (xz - yw)) * scale[0],
    0,
    (2 * (xy - zw)) * scale[1],
    (1 - 2 * (x2 + z2)) * scale[1],
    (2 * (yz + xw)) * scale[1],
    0,
    (2 * (xz + yw)) * scale[2],
    (2 * (yz - xw)) * scale[2],
    (1 - 2 * (x2 + y2)) * scale[2],
    0,
    translation[0],
    translation[1],
    translation[2],
    1,
  ];
}

List<double> _vector3(Object? value, List<num> fallback) {
  if (value is List && value.length == 3) {
    return value.map((item) => (item as num).toDouble()).toList();
  }
  return fallback.map((item) => item.toDouble()).toList();
}

List<double> _multiplyMatrices(List<double> a, List<double> b) {
  final result = List<double>.filled(16, 0);
  for (var column = 0; column < 4; column++) {
    for (var row = 0; row < 4; row++) {
      for (var index = 0; index < 4; index++) {
        result[column * 4 + row] +=
            a[index * 4 + row] * b[column * 4 + index];
      }
    }
  }
  return result;
}
