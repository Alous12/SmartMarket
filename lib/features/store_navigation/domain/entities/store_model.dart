import 'dart:math' as math;
import 'dart:typed_data';

enum Supermarket {
  natural(
    title: 'Supermercado_1',
    shortTitle: 'Mini_Market',
    assetPath: 'Modelos_3D/supermercado_1.glb',
  ),
  piloto(
    title: 'SmartMarket_2',
    shortTitle: 'SuperMarket',
    assetPath: 'Modelos_3D/supermercado_2.glb',
  );

  const Supermarket({
    required this.title,
    required this.shortTitle,
    required this.assetPath,
  });

  final String title;
  final String shortTitle;
  final String assetPath;
}

class StoreModel {
  const StoreModel({
    required this.store,
    required this.bytes,
    required this.metadata,
  });

  final Supermarket store;
  final Uint8List bytes;
  final StoreModelMetadata metadata;
}

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.name,
    this.category = '',
    this.routeNode = '',
  });

  final String id;
  final String name;
  final String category;
  final String routeNode;
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
  });

  final int byteLength;
  final int triangles;
  final int meshInstances;
  final int materials;
  final List<String> routeNodeIds;
  final List<String> productIds;
  final List<StoreRouteNode> routeNodes;
  final List<StoreProduct> products;
}
