import 'dart:typed_data';

/// Supermercados disponibles en la app. Cada uno es un GLB exportado desde Blender
/// con el mismo esquema de extras (product_group, product_box, route_node).
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

/// Portable model data; no dependency on Flutter or the rendering engine.
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

/// Producto editable del modelo (un grupo de cajas con la misma etiqueta).
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.name,
    this.category = '',
    this.routeNode = '',
  });

  final String id;

  /// Nombre original guardado en el .blend / GLB.
  final String name;
  final String category;
  final String routeNode;
}

class StoreModelMetadata {
  const StoreModelMetadata({
    required this.byteLength,
    required this.triangles,
    required this.meshInstances,
    required this.materials,
    required this.routeNodeIds,
    required this.productIds,
    this.products = const [],
  });

  final int byteLength;
  final int triangles;
  final int meshInstances;
  final int materials;
  final List<String> routeNodeIds;
  final List<String> productIds;
  final List<StoreProduct> products;
}
