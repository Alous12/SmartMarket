import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/store_model.dart';
import '../../domain/repositories/store_model_repository.dart';
import '../datasources/glb_metadata_reader.dart';

class AssetStoreModelRepository implements StoreModelRepository {
  AssetStoreModelRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  @override
  Future<StoreModel> load(Supermarket store) async {
    final data = await _bundle.load(store.assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final metadata = await compute(readGlbMetadata, bytes);
    return StoreModel(store: store, bytes: bytes, metadata: metadata);
  }
}
