import 'package:flutter/material.dart';

import '../../domain/entities/store_model.dart';

Future<List<String>?> showRoutePlannerSheet(
  BuildContext context, {
  required List<StoreProduct> products,
  required Map<String, String> productNames,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: _RoutePlannerSheet(
        products: products,
        productNames: productNames,
      ),
    ),
  );
}

class _RoutePlannerSheet extends StatefulWidget {
  const _RoutePlannerSheet({
    required this.products,
    required this.productNames,
  });

  final List<StoreProduct> products;
  final Map<String, String> productNames;

  @override
  State<_RoutePlannerSheet> createState() => _RoutePlannerSheetState();
}

class _RoutePlannerSheetState extends State<_RoutePlannerSheet> {
  final _selectedIds = <String>{};
  String _query = '';

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u');

  @override
  Widget build(BuildContext context) {
    final query = _normalize(_query.trim());
    final visible = widget.products.where((product) {
      final name = widget.productNames[product.id] ?? product.name;
      return query.isEmpty ||
          _normalize('$name ${product.category} ${product.id}').contains(
            query,
          );
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planificar ruta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text('Selecciona productos · inicio desde la entrada'),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar productos',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${_selectedIds.length} productos seleccionados'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final product = visible[index];
              final canRoute = product.routeNode.isNotEmpty;
              final name = widget.productNames[product.id] ?? product.name;
              return CheckboxListTile(
                value: _selectedIds.contains(product.id),
                onChanged: canRoute
                    ? (selected) => setState(() {
                        if (selected == true) {
                          _selectedIds.add(product.id);
                        } else {
                          _selectedIds.remove(product.id);
                        }
                      })
                    : null,
                title: Text(name),
                subtitle: Text(
                  canRoute
                      ? '${product.category.isEmpty ? 'Producto' : product.category} · ${product.routeNode}'
                      : 'Este producto no tiene un nodo de ruta en el modelo',
                ),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () => Navigator.pop(context, _selectedIds.toList()),
              icon: const Icon(Icons.route),
              label: Text('Calcular ruta (${_selectedIds.length})'),
            ),
          ),
        ),
      ],
    );
  }
}
