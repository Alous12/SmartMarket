import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/store_providers.dart';
import '../../domain/entities/store_model.dart';

final storeModelProvider = FutureProvider.autoDispose<StoreModel>(
  (ref) => ref.watch(storeModelRepositoryProvider).load(),
  retry: (count, error) => null,
);
