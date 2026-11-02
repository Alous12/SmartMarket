import 'package:flutter/material.dart';

import '../../domain/entities/store_model.dart';

/// Hoja para elegir los productos de la ruta. Devuelve los ids de caja elegidos.
Future<List<String>?> showRoutePicker(
  BuildContext context, {
  required List<StoreProduct> products,
  required List<String> selected,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => _RoutePicker(
        products: products,
        initial: selected,
        controller: controller,
      ),
    ),
  );
}

class _RoutePicker extends StatefulWidget {
  const _RoutePicker({
    required this.products,
    required this.initial,
    required this.controller,
  });

  final List<StoreProduct> products;
  final List<String> initial;
  final ScrollController controller;

  @override
  State<_RoutePicker> createState() => _RoutePickerState();
}

class _RoutePickerState extends State<_RoutePicker> {
  late final Set<String> _selected = {...widget.initial};
  String _query = '';

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úù]'), 'u');

  // Solo se pueden elegir productos con stock y con un nodo de ruta en el modelo.
  bool _selectable(StoreProduct p) =>
      p.routeNode.isNotEmpty && (p.stock ?? 1) > 0;

  @override
  Widget build(BuildContext context) {
    final query = _normalize(_query.trim());
    final visible = widget.products
        .where(
          (p) =>
              query.isEmpty ||
              _normalize('${p.name} ${p.category}').contains(query),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Elige tus productos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
            controller: widget.controller,
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final product = visible[index];
              final enabled = _selectable(product);
              return CheckboxListTile(
                value: _selected.contains(product.id),
                onChanged: enabled
                    ? (value) => setState(() {
                        if (value == true) {
                          _selected.add(product.id);
                        } else {
                          _selected.remove(product.id);
                        }
                      })
                    : null,
                title: Text(product.name),
                subtitle: Text(
                  [
                    if (product.category.isNotEmpty) product.category,
                    if (!enabled) 'Agotado',
                  ].join(' · '),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_selected.clear),
                    child: const Text('Limpiar'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _selected.toList()),
                  child: Text(
                    _selected.isEmpty
                        ? 'Quitar ruta'
                        : 'Crear ruta (${_selected.length})',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
