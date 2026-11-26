import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_or_error_state.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/store_model.dart';
import '../../domain/services/store_layout.dart';
import '../controllers/product_creation.dart';
import '../providers/store_model_provider.dart';
import '../widgets/product_sheets.dart';

/// Productos de la sucursal elegida. Tocar uno lo señala en el mapa 3D.
class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  void _showInMap(BuildContext context, WidgetRef ref, StoreProduct product) {
    ref.read(mapRequestProvider.notifier).send(FocusProductRequest(product.id));
    context.goNamed('supermarket');
  }

  /// Abre el mapa directamente en «Editar tienda» (para el admin, su plano 2D).
  void _editStore(BuildContext context, WidgetRef ref) {
    ref.read(mapRequestProvider.notifier).send(const StartEditRequest());
    context.goNamed('supermarket');
  }

  /// Lleva al plano para poner en un estante un producto del inventario.
  void _place(BuildContext context, WidgetRef ref, StoreProduct product) {
    final dbId = product.dbId;
    if (dbId == null) return;
    ref.read(mapRequestProvider.notifier).send(PlaceProductRequest(dbId));
    context.goNamed('supermarket');
  }

  Future<void> _createProduct(
    BuildContext context,
    WidgetRef ref,
    StoreModel model,
  ) async {
    if (!model.fromCatalog) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay conexión con el servidor: no se pueden crear productos ahora.',
          ),
        ),
      );
      return;
    }
    await createProductFlow(
      context,
      ref,
      layout: buildStoreLayout(
        products: model.metadata.products,
        emptySlots: model.emptySlots,
      ),
    );
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
    final isAdmin =
        ref.watch(authControllerProvider).asData?.value?.isAdmin ?? false;
    final body = AnimatedSwitcher(
      duration: AppTheme.motion(context, AppTheme.medium),
      child: model.when(
        loading: () => const _ProductsSkeleton(key: ValueKey('loading')),
        error: (error, stack) => EmptyOrErrorState(
          key: const ValueKey('error'),
          title: 'No se pudieron cargar los productos.',
          message:
              'Revisa tu conexión o que el servidor esté encendido e inténtalo otra vez.',
          onRetry: () => ref.invalidate(storeModelProvider),
        ),
        data: (model) => ProductListView(
          key: const ValueKey('data'),
          store: model.store,
          products: model.metadata.products,
          admin: isAdmin,
          onEditStore: isAdmin ? () => _editStore(context, ref) : null,
          onAskAssistant: isAdmin ? () => context.goNamed('assistant') : null,
          onOpenUsers: isAdmin ? () => context.pushNamed('users') : null,
          unplaced: isAdmin ? model.unplaced : const [],
          onCreateProduct: isAdmin
              ? () => _createProduct(context, ref, model)
              : null,
          onPlace: isAdmin ? (product) => _place(context, ref, product) : null,
          onSelected: (product) => _showInMap(context, ref, product),
          onRename: (product) => _rename(context, ref, product),
        ),
      ),
    );
    // El admin tiene su cabecera oscura; el cliente, el título grande.
    if (isAdmin && model.hasValue) return Scaffold(body: body);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              child: Semantics(
                header: true,
                child: const Text(
                  'Productos',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _ProductsSkeleton extends StatelessWidget {
  const _ProductsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      children: [
        const SkeletonBox(height: 62, radius: AppTheme.radiusL),
        const SizedBox(height: 16),
        const Row(
          children: [
            SkeletonBox(width: 74, height: 48, radius: 24),
            SizedBox(width: 10),
            SkeletonBox(width: 96, height: 48, radius: 24),
            SizedBox(width: 10),
            SkeletonBox(width: 86, height: 48, radius: 24),
          ],
        ),
        const SizedBox(height: 16),
        for (var row = 0; row < 3; row++) ...[
          const Row(
            children: [
              Expanded(
                child: SkeletonBox(height: 236, radius: AppTheme.radiusXL),
              ),
              SizedBox(width: 14),
              Expanded(
                child: SkeletonBox(height: 236, radius: AppTheme.radiusXL),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
