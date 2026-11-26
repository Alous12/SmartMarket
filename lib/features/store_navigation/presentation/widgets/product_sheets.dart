import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/store_model.dart';
import '../providers/store_model_provider.dart';

/// Resultado de [showProductEditor] cuando el admin pide quitar el producto.
const productRemoveRequest = '\u0000remove';

/// Diálogo para renombrar un producto. Devuelve el nombre nuevo, una cadena
/// vacía para volver al nombre original, [productRemoveRequest] para quitarlo
/// de la sucursal, o null si se cancela.
Future<String?> showProductEditor(
  BuildContext context, {
  required StoreProduct product,
  required String currentName,
  bool canRemove = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ProductEditor(
      product: product,
      currentName: currentName,
      canRemove: canRemove,
    ),
  );
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({
    required this.product,
    required this.currentName,
    required this.canRemove,
  });

  final StoreProduct product;
  final String currentName;
  final bool canRemove;

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
          if (widget.canRemove)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, productRemoveRequest),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Quitar de la sucursal'),
              ),
            ),
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
class ProductListView extends ConsumerStatefulWidget {
  const ProductListView({
    super.key,
    required this.store,
    required this.products,
    required this.onSelected,
    required this.onRename,
  });

  final Supermarket store;
  final List<StoreProduct> products;
  final ValueChanged<StoreProduct> onSelected;
  final ValueChanged<StoreProduct> onRename;

  @override
  ConsumerState<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends ConsumerState<ProductListView> {
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
        _InventoryDashboard(products: widget.products),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.store.title} · ${widget.products.length} productos'
                  '${names.isEmpty ? '' : ' · ${names.length} renombrados'}',
                  style: theme.textTheme.bodySmall,
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
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final product = visible[index];
              final renamed = names[product.id];
              return ListTile(
                title: Text(renamed ?? product.name),
                subtitle: Text(
                  [
                    if (product.category.isNotEmpty) product.category,
                    if (product.stock != null)
                      product.stock! > 0
                          ? 'Stock: ${product.stock!.toStringAsFixed(product.stock! % 1 == 0 ? 0 : 2)}'
                          : 'Agotado',
                    if (renamed != null) 'antes: ${product.name}',
                  ].join(' · '),
                ),
                leading: Icon(
                  renamed == null
                      ? Icons.inventory_2_outlined
                      : Icons.edit_note,
                ),
                trailing: IconButton(
                  tooltip: 'Renombrar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => widget.onRename(product),
                ),
                onTap: () => widget.onSelected(product),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InventoryDashboard extends StatelessWidget {
  const _InventoryDashboard({required this.products});

  final List<StoreProduct> products;

  @override
  Widget build(BuildContext context) {
    final stocked = products.where((product) => product.stock != null).toList();
    if (stocked.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: AppTheme.green),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'El inventario detallado aún no está disponible.',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final lowStock =
        stocked
            .where((product) => product.stock! > 0 && product.stock! <= 5)
            .toList()
          ..sort((a, b) => a.stock!.compareTo(b.stock!));
    final outOfStock = stocked.where((product) => product.stock == 0).length;
    final units = stocked.fold<double>(
      0,
      (sum, product) => sum + product.stock!,
    );
    final value = stocked.fold<double>(
      0,
      (sum, product) => sum + (product.price ?? 0) * product.stock!,
    );
    final categories = stocked
        .map((product) => product.category)
        .toSet()
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Resumen del inventario',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth > 520
                  ? (constraints.maxWidth - 24) / 3
                  : (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'Productos',
                      value: '${stocked.length}',
                      helper: '$categories categorías',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      icon: Icons.category_outlined,
                      label: 'Unidades',
                      value: _compactNumber(units),
                      helper: 'disponibles',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      icon: Icons.payments_outlined,
                      label: 'Valor',
                      value: '\$${_compactNumber(value)}',
                      helper: 'precio × stock',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'Por agotarse',
                      value: '${lowStock.length}',
                      helper: '$outOfStock agotados',
                      warning: lowStock.isNotEmpty || outOfStock > 0,
                    ),
                  ),
                ],
              );
            },
          ),
          if (lowStock.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              color: const Color(0xFFFFF6E5),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.priority_high,
                          size: 18,
                          color: Color(0xFFB26A00),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Prioridad de reposición',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final product in lowStock.take(4))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Reponer: ${product.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${_compactNumber(product.stock!)} disponibles',
                              style: const TextStyle(
                                color: Color(0xFF9A5700),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final tint = warning ? const Color(0xFFFFF6E5) : AppTheme.tint;
    final color = warning ? const Color(0xFFB26A00) : AppTheme.green;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: tint,
              foregroundColor: color,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    helper,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _compactNumber(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}
