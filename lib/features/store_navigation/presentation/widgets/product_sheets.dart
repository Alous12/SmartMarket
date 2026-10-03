import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/store_model.dart';
import '../providers/store_model_provider.dart';

/// Acción elegida en la lista de productos.
class ProductListAction {
  const ProductListAction(this.productId, {this.edit = false});

  final String productId;
  final bool edit;
}

/// Diálogo para renombrar un producto. Devuelve el nombre nuevo, una cadena
/// vacía para volver al nombre original, o null si se cancela.
Future<String?> showProductEditor(
  BuildContext context, {
  required StoreProduct product,
  required String currentName,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _ProductEditor(product: product, currentName: currentName),
  );
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({required this.product, required this.currentName});

  final StoreProduct product;
  final String currentName;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  late final _controller = TextEditingController(text: widget.currentName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final theme = Theme.of(context);
    final changed = widget.currentName != product.name;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nombre del producto', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            [
              product.id,
              if (product.category.isNotEmpty) product.category,
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre visible en el mapa',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          if (changed)
            Text(
              'Nombre original: ${product.name}',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (changed)
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, ''),
                  icon: const Icon(Icons.restore),
                  label: const Text('Restaurar'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: const Text('Guardar')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lista buscable de los productos del supermercado.
Future<ProductListAction?> showProductList(
  BuildContext context, {
  required Supermarket store,
  required List<StoreProduct> products,
}) {
  return showModalBottomSheet<ProductListAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => _ProductList(
        store: store,
        products: products,
        scrollController: scrollController,
      ),
    ),
  );
}

class _ProductList extends ConsumerStatefulWidget {
  const _ProductList({
    required this.store,
    required this.products,
    required this.scrollController,
  });

  final Supermarket store;
  final List<StoreProduct> products;
  final ScrollController scrollController;

  @override
  ConsumerState<_ProductList> createState() => _ProductListState();
}

class _ProductListState extends ConsumerState<_ProductList> {
  String _query = '';

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úù]'), 'u');

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(productNamesProvider).value ?? const {};
    final query = _normalize(_query.trim());
    final visible = widget.products.where((product) {
      if (query.isEmpty) return true;
      final name = names[product.id] ?? product.name;
      return _normalize(
        '$name ${product.category} ${product.id}',
      ).contains(query);
    }).toList();
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Productos', style: theme.textTheme.titleLarge),
                    Text(
                      '${widget.store.title} · ${widget.products.length} productos'
                      '${names.isEmpty ? '' : ' · ${names.length} renombrados'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (names.isNotEmpty)
                TextButton(
                  onPressed: () =>
                      ref.read(productNamesProvider.notifier).resetAll(),
                  child: const Text('Restablecer'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por nombre o categoría',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final product = visible[index];
              final renamed = names[product.id];
              return ListTile(
                title: Text(renamed ?? product.name),
                subtitle: Text(
                  [
                    if (product.category.isNotEmpty) product.category,
                    if (renamed != null) 'antes: ${product.name}',
                  ].join(' · '),
                ),
                leading: Icon(
                  renamed == null ? Icons.inventory_2_outlined : Icons.edit_note,
                ),
                trailing: IconButton(
                  tooltip: 'Renombrar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.pop(
                    context,
                    ProductListAction(product.id, edit: true),
                  ),
                ),
                onTap: () =>
                    Navigator.pop(context, ProductListAction(product.id)),
              );
            },
          ),
        ),
      ],
    );
  }
}
