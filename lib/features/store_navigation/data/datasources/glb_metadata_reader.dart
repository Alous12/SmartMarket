import 'dart:convert';
import 'dart:typed_data';

import '../../domain/entities/floor_plan.dart';
import '../../domain/entities/store_model.dart';
import 'floor_plan_builder.dart';

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
  // Muebles y paredes para el plano del piso (sin cajas ni etiquetas).
  final obstacleMeshes = <(int, List<double>)>[];
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
      final matrix = worldMatrix(index);
      products.putIfAbsent(
        id,
        () => StoreProduct(
          id: id,
          name: (extras['display_name'] ?? id).toString(),
          category: (extras['category'] ?? '').toString(),
          routeNode: (extras['route_node'] ?? '').toString(),
          slotId: (extras['slot_id'] ?? '').toString(),
          x: matrix[12],
          z: matrix[14],
        ),
      );
    }
    if (node['mesh'] == null) continue;
    instances++;
    if (extras['kind'] != 'product_box' && extras['kind'] != 'editable_label') {
      obstacleMeshes.add((node['mesh'] as int, worldMatrix(index)));
    }
    for (final primitive in meshes[node['mesh']]['primitives'] as List) {
      if ((primitive['mode'] ?? 4) != 4) continue;
      final accessor =
          primitive['indices'] ?? primitive['attributes']['POSITION'];
      triangles += (accessors[accessor]['count'] as int) ~/ 3;
    }
  }
  // Muebles del modelo: sirven para completar el grafo y para la línea recta.
  FloorPlan? obstacles;
  try {
    obstacles = buildObstaclePlan(
      triangles: _readTriangles(json, bytes, data, jsonLength, obstacleMeshes),
      nodes: routeNodes.values.toList(growable: false),
    );
  } on Object {
    // Sin plano la ruta sigue los pasillos del grafo, como antes.
    obstacles = null;
  }
  final resolvedRouteNodes =
      routeNodes.values.every((node) => node.neighbors.isEmpty)
      ? _buildAisleFallbackGraph(
          routeNodes.values,
          canCross: obstacles == null
              ? null
              : (a, b) => obstacles!.isClear(a.x, a.z, b.x, b.z),
        )
      : routeNodes.values.toList(growable: false);
  final floorPlan = obstacles == null
      ? null
      : walkablePlan(obstacles: obstacles, nodes: resolvedRouteNodes);
  return StoreModelMetadata(
    byteLength: bytes.length,
    triangles: triangles,
    meshInstances: instances,
    materials: ((json['materials'] as List?) ?? []).length,
    routeNodeIds: List.unmodifiable(routeIds),
    routeNodes: List.unmodifiable(resolvedRouteNodes),
    productIds: List.unmodifiable(productIds),
    products: List.unmodifiable(products.values),
    floorPlan: floorPlan,
  );
}

/// Triángulos de [meshes] en coordenadas del mapa, 9 números por triángulo.
Float64List _readTriangles(
  Map<String, dynamic> json,
  Uint8List bytes,
  ByteData data,
  int jsonLength,
  List<(int, List<double>)> meshes,
) {
  final binStart = 20 + jsonLength;
  if (meshes.isEmpty || binStart + 8 > bytes.length) return Float64List(0);
  final binLength = data.getUint32(binStart, Endian.little);
  if (data.getUint32(binStart + 4, Endian.little) != 0x004E4942 ||
      binStart + 8 + binLength > bytes.length) {
    return Float64List(0);
  }
  final bin = ByteData.sublistView(
    bytes,
    binStart + 8,
    binStart + 8 + binLength,
  );
  final accessors = (json['accessors'] as List?) ?? const [];
  final views = (json['bufferViews'] as List?) ?? const [];
  final meshList = (json['meshes'] as List?) ?? const [];

  // Lector de un accessor: devuelve el componente [component] del elemento [i].
  num Function(int i, int component) reader(int accessorIndex) {
    final accessor = accessors[accessorIndex] as Map<String, dynamic>;
    final view = views[accessor['bufferView'] as int] as Map<String, dynamic>;
    if ((view['buffer'] ?? 0) != 0 || accessor['sparse'] != null) {
      throw const FormatException('Accessor no soportado.');
    }
    final type = accessor['componentType'] as int;
    final size = switch (type) {
      5126 || 5125 => 4,
      5123 => 2,
      5121 => 1,
      _ => throw const FormatException('Tipo de componente no soportado.'),
    };
    final components = accessor['type'] == 'VEC3' ? 3 : 1;
    final offset =
        ((view['byteOffset'] ?? 0) as int) +
        ((accessor['byteOffset'] ?? 0) as int);
    final stride = (view['byteStride'] as int?) ?? size * components;
    return (i, component) {
      final at = offset + i * stride + component * size;
      return switch (type) {
        5126 => bin.getFloat32(at, Endian.little),
        5125 => bin.getUint32(at, Endian.little),
        5123 => bin.getUint16(at, Endian.little),
        _ => bin.getUint8(at),
      };
    };
  }

  final out = <double>[];
  for (final (meshIndex, m) in meshes) {
    final primitives =
        (meshList[meshIndex] as Map<String, dynamic>)['primitives'] as List;
    for (final primitive in primitives.cast<Map<String, dynamic>>()) {
      if ((primitive['mode'] ?? 4) != 4) continue;
      final positionIndex =
          (primitive['attributes'] as Map<String, dynamic>)['POSITION'] as int;
      final position = reader(positionIndex);
      final vertexCount =
          (accessors[positionIndex] as Map<String, dynamic>)['count'] as int;
      final indicesIndex = primitive['indices'] as int?;
      final index = indicesIndex == null ? null : reader(indicesIndex);
      final count = indicesIndex == null
          ? vertexCount
          : (accessors[indicesIndex] as Map<String, dynamic>)['count'] as int;
      for (var i = 0; i + 2 < count; i += 3) {
        for (var corner = 0; corner < 3; corner++) {
          final vertex = index == null
              ? i + corner
              : index(i + corner, 0).toInt();
          final x = position(vertex, 0).toDouble();
          final y = position(vertex, 1).toDouble();
          final z = position(vertex, 2).toDouble();
          out
            ..add(m[0] * x + m[4] * y + m[8] * z + m[12])
            ..add(m[1] * x + m[5] * y + m[9] * z + m[13])
            ..add(m[2] * x + m[6] * y + m[10] * z + m[14]);
        }
      }
    }
  }
  return Float64List.fromList(out);
}

/// The Natural model predates route metadata. Its `node_pasillo_CC_RR` nodes
/// describe a grid of longitudinal aisles (CC) and their ordered positions
/// (RR). Shelves lie between aisles, so the first and last row form transverse
/// corridors. A middle row is a corridor too when [canCross] finds no shelf
/// between two neighbouring aisles (a gap between gondolas). Connecting all
/// nearby points blindly would cut through them.
List<StoreRouteNode> _buildAisleFallbackGraph(
  Iterable<StoreRouteNode> nodes, {
  bool Function(StoreRouteNode a, StoreRouteNode b)? canCross,
}) {
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

  // Filas intermedias: se cruza de un pasillo al de al lado solo si no hay un
  // estante en medio.
  if (canCross != null) {
    final rows = {
      for (final aisle in aisles.values)
        for (final entry in aisle) entry.row,
    };
    for (final row in rows) {
      for (var index = 1; index < orderedAisles.length; index++) {
        final from = aisles[orderedAisles[index - 1]]!
            .where((node) => node.row == row)
            .firstOrNull;
        final to = aisles[orderedAisles[index]]!
            .where((node) => node.row == row)
            .firstOrNull;
        if (from == null || to == null) continue;
        if (canCross(from.node, to.node)) connect(from.node.id, to.node.id);
      }
    }
  }

  // Cada caja es un carril: fila -> pago -> salida. Los mostradores separan los
  // carriles, así que el punto de pago solo se alcanza por su propio carril.
  final lanePattern = RegExp(r'^node_caja_(\d+)_(fila|pago|salida)$');
  final lanes = <String, Map<String, String>>{};
  for (final node in routeNodes) {
    final match = lanePattern.firstMatch(node.id);
    if (match == null) continue;
    lanes.putIfAbsent(match.group(1)!, () => {})[match.group(2)!] = node.id;
  }
  for (final lane in lanes.values) {
    final fila = lane['fila'], pago = lane['pago'], salida = lane['salida'];
    if (fila != null && pago != null) connect(fila, pago);
    if (pago != null && salida != null) connect(pago, salida);
  }

  final specialNodes = routeNodes.where(
    (node) =>
        aislePattern.firstMatch(node.id) == null && !node.id.endsWith('_pago'),
  );
  for (final node in specialNodes) {
    final closest =
        routeNodes.where((candidate) => candidate.id != node.id).toList()
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
        result[column * 4 + row] += a[index * 4 + row] * b[column * 4 + index];
      }
    }
  }
  return result;
}
