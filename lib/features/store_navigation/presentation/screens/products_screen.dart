import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/store_model.dart';
import '../providers/store_model_provider.dart';
import '../widgets/map_widgets.dart';
import '../widgets/product_sheets.dart';

/// Productos de la sucursal elegida. Tocar uno lo señala en el mapa 3D.
class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  void _showInMap(BuildContext context, WidgetRef ref, StoreProduct product) {
    ref.read(mapRequestProvider.notifier).send(FocusProductRequest(product.id));
    context.goNamed('supermarket');
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    StoreProduct product,
  ) async {
    final names = ref.read(productNamesProvider).value ?? const {};
    final result = await showProductEditor(
      context,
      product: product,
      currentName: names[product.id] ?? product.name,
    );
    if (result != null) {
      await ref.read(productNamesProvider.notifier).rename(product, result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(storeModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Productos',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
      body: model.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.green),
        ),
        error: (error, stack) => CenteredMessage(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudieron cargar los productos.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(storeModelProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (model) => ProductListView(
          store: model.store,
          products: model.metadata.products,
          onSelected: (product) => _showInMap(context, ref, product),
          onRename: (product) => _rename(context, ref, product),
        ),
      ),
    );
  }
}
