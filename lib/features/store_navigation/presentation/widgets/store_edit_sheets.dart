import 'package:flutter/material.dart';

import '../../domain/entities/store_model.dart';

enum SlotAction { pickUp, drop, edit, remove, create }

/// Acciones disponibles cuando el avatar llega a un espacio de la estantería.
/// [product] es null si el espacio está libre; [carrying] es el producto en mano.
Future<SlotAction?> showSlotActions(
  BuildContext context, {
  StoreProduct? product,
  StoreProduct? carrying,
}) {
  final actions = <(SlotAction, IconData, String)>[
    if (product == null && carrying != null)
      (SlotAction.drop, Icons.download_done, 'Dejar "${carrying.name}" aquí'),
    if (product == null && carrying == null)
      (SlotAction.create, Icons.add_circle_outline, 'Agregar producto nuevo'),
    if (product != null && carrying != null)
      (
        SlotAction.drop,
        Icons.swap_horiz,
        'Intercambiar con "${carrying.name}"',
      ),
    if (product != null && carrying == null) ...[
      (SlotAction.pickUp, Icons.back_hand_outlined, 'Recoger para moverlo'),
      (SlotAction.edit, Icons.edit_outlined, 'Editar nombre, precio y stock'),
      (SlotAction.remove, Icons.delete_outline, 'Quitar de la sucursal'),
    ],
  ];
  return showModalBottomSheet<SlotAction>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              product?.name ?? 'Espacio libre',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (product != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [
                    if (product.price != null)
                      '\$${product.price!.toStringAsFixed(2)}',
                    if (product.stock != null)
                      'Stock: ${product.stock!.toStringAsFixed(0)}',
                  ].join(' · '),
                ),
              ),
            const SizedBox(height: 8),
            for (final (action, icon, label) in actions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.pop(context, action),
              ),
          ],
        ),
      ),
    ),
  );
}

class ProductFormResult {
  const ProductFormResult({
    required this.name,
    required this.price,
    required this.stock,
    this.categoryId,
  });

  final String name;
  final double price;
  final double stock;
  final int? categoryId;
}

/// Formulario de producto. Con [categories] pide también la categoría (producto nuevo).
Future<ProductFormResult?> showProductForm(
  BuildContext context, {
  required String title,
  String name = '',
  double? price,
  double? stock,
  Map<int, String>? categories,
}) {
  return showDialog<ProductFormResult>(
    context: context,
    builder: (context) => _ProductForm(
      title: title,
      name: name,
      price: price,
      stock: stock,
      categories: categories,
    ),
  );
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({
    required this.title,
    required this.name,
    this.price,
    this.stock,
    this.categories,
  });

  final String title;
  final String name;
  final double? price;
  final double? stock;
  final Map<int, String>? categories;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  late final _price = TextEditingController(
    text: widget.price?.toStringAsFixed(2) ?? '',
  );
  late final _stock = TextEditingController(
    text: widget.stock?.toStringAsFixed(0) ?? '',
  );
  int? _categoryId;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  String? _number(String? value) {
    final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
    return parsed == null || parsed < 0 ? 'Número inválido' : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ProductFormResult(
        name: _name.text.trim(),
        price: double.parse(_price.text.replaceAll(',', '.')),
        stock: double.parse(_stock.text.replaceAll(',', '.')),
        categoryId: _categoryId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre'),
                maxLength: 150,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
              ),
              TextFormField(
                controller: _price,
                decoration: const InputDecoration(labelText: 'Precio'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _number,
              ),
              TextFormField(
                controller: _stock,
                decoration: const InputDecoration(labelText: 'Stock'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _number,
              ),
              if (widget.categories != null)
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    for (final entry in widget.categories!.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (v) => v == null ? 'Elige una categoría' : null,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
