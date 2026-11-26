import 'dart:math' as math;
import 'dart:typed_data';

import 'floor_plan.dart';

enum Supermarket {
  natural(
    title: 'Supermercado_1',
    shortTitle: 'Mini_Market',
    assetPath: 'Modelos_3D/supermercado_1.glb',
    mapNorthDegrees: 0,
  ),
  piloto(
    title: 'SmartMarket_2',
    shortTitle: 'SuperMarket',
    assetPath: 'Modelos_3D/supermercado_2.glb',
    mapNorthDegrees: 0,
  );

  const Supermarket({
    required this.title,
    required this.shortTitle,
    required this.assetPath,
    required this.mapNorthDegrees,
  });

  final String title;
  final String shortTitle;
  final String assetPath;

  /// Dónde está el norte real: grados en sentido horario desde la parte superior
  /// del mapa. Con 0, arriba del mapa es el norte; se mide con una brújula en cada
  /// local.
  final double mapNorthDegrees;
}

class StoreModel {
  const StoreModel({
    required this.store,
    required this.bytes,
    required this.metadata,
    this.fromCatalog = false,
    this.emptySlots = const [],
    this.unplaced = const [],
    this.branchId,
  });

  final Supermarket store;
  final Uint8List bytes;
  final StoreModelMetadata metadata;

  /// Espacios del modelo sin producto en la base de datos (cajas ocultas).
  final List<StoreProduct> emptySlots;

  /// Productos del inventario de la sucursal que no están en ningún espacio del
  /// modelo (recién creados o retirados del estante). No tienen caja en el mapa:
  /// su [StoreProduct.id] es `db:<id>` y [StoreProduct.slotId] está vacío.
  final List<StoreProduct> unplaced;

  /// Id de la sucursal en la base de datos (null si el backend no respondió).
  final int? branchId;

  /// Verdadero si `metadata.products` viene de la base de datos: solo esos
  /// productos existen en la sucursal.
  final bool fromCatalog;
}

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.name,
    this.category = '',
    this.routeNode = '',
    this.price,
    this.stock,
    this.dbId,
    this.slotId = '',
    this.x,
    this.z,
    this.section,
    this.shelf,
    this.shelfId,
  });

  final String id;
  final String name;
  final String category;

  /// Sección y estante en la base de datos (null si no se cargaron).
  final String? section;
  final String? shelf;
  final String routeNode;
  final double? price;
  final double? stock;

  /// Espacio de estantería del modelo (slot_id del GLB) donde está la caja.
  final String slotId;

  /// Estante del modelo (shelf_id del GLB) al que pertenece [slotId].
  final String? shelfId;

  /// Id del producto en la base de datos (null si solo existe en el modelo).
  final int? dbId;

  /// Posición del producto en el mapa (null si el modelo no la indica). Sirve
  /// para decir a qué lado del pasillo está.
  final double? x;
  final double? z;

  StoreProduct copyWith({
    String? name,
    String? category,
    double? price,
    double? stock,
    int? dbId,
    String? section,
    String? shelf,
  }) => StoreProduct(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    routeNode: routeNode,
    slotId: slotId,
    price: price ?? this.price,
    stock: stock ?? this.stock,
    dbId: dbId ?? this.dbId,
    x: x,
    z: z,
    section: section ?? this.section,
    shelf: shelf ?? this.shelf,
    shelfId: shelfId,
  );
}

class StoreRouteNode {
  const StoreRouteNode({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.neighbors,
  });

  final String id;
  final double x;
  final double y;
  final double z;
  final List<String> neighbors;

  double distanceTo(StoreRouteNode other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}

class StoreModelMetadata {
  const StoreModelMetadata({
    required this.byteLength,
    required this.triangles,
    required this.meshInstances,
    required this.materials,
    required this.routeNodeIds,
    required this.productIds,
    this.routeNodes = const [],
    this.products = const [],
    this.floorPlan,
  });

  final int byteLength;
  final int triangles;
  final int meshInstances;
  final int materials;
  final List<String> routeNodeIds;
  final List<String> productIds;
  final List<StoreRouteNode> routeNodes;
  final List<StoreProduct> products;

  /// Dónde hay muebles y dónde se puede caminar (null si no se pudo leer).
  final FloorPlan? floorPlan;

  StoreModelMetadata withProducts(List<StoreProduct> products) =>
      StoreModelMetadata(
        byteLength: byteLength,
        triangles: triangles,
        meshInstances: meshInstances,
        materials: materials,
        routeNodeIds: routeNodeIds,
        productIds: productIds,
        routeNodes: routeNodes,
        products: List.unmodifiable(products),
        floorPlan: floorPlan,
      );
}
