import 'dart:typed_data';

/// Portable model data; no dependency on Flutter or the rendering engine.
class StoreModel {
  const StoreModel({required this.bytes, required this.metadata});

  final Uint8List bytes;
  final StoreModelMetadata metadata;
}

class StoreModelMetadata {
  const StoreModelMetadata({
    required this.byteLength,
    required this.triangles,
    required this.meshInstances,
    required this.materials,
    required this.routeNodeIds,
    required this.productIds,
  });

  final int byteLength;
  final int triangles;
  final int meshInstances;
  final int materials;
  final List<String> routeNodeIds;
  final List<String> productIds;
}
