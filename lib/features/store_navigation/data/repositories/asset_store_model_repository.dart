import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/store_model.dart';
import '../../domain/repositories/store_model_repository.dart';
import '../datasources/glb_metadata_reader.dart';

class AssetStoreModelRepository implements StoreModelRepository {
  AssetStoreModelRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  static const assetPath = 'Modelos_3D/supermercado_1.glb';

  @override
  Future<StoreModel> load() async {
    final data = await _bundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final metadata = await compute(readGlbMetadata, bytes);
    return StoreModel(bytes: bytes, metadata: metadata);
  }
}
