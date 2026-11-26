import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sm_buttons.dart';
import '../../../../core/widgets/sm_text_field.dart';
import '../../data/catalog_api.dart';
import '../../domain/services/store_layout.dart';
import 'layout_sheets.dart';

/// Unidades de medida que se ofrecen al crear un producto.
const productUnits = [
  'unidad',
  'kg',
  'g',
  'litro',
  'ml',
  'paquete',
  'caja',
  'docena',
];

/// «Crear producto» a pantalla completa: datos del producto y dónde va (un
/// espacio libre del plano o solo el inventario). Con [presetSlot] el espacio
/// ya viene elegido desde el plano.
Future<NewCatalogProduct?> showNewProductForm(
  BuildContext context, {
  required Map<int, String> categories,
  StoreLayout? layout,
  String? presetSlot,
}) {
  return Navigator.of(context, rootNavigator: true).push<NewCatalogProduct>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => NewProductFormScreen(
        categories: categories,
        layout: layout,
        presetSlot: presetSlot,
      ),
    ),
  );
}

class NewProductFormScreen extends StatefulWidget {
  const NewProductFormScreen({
    super.key,
    required this.categories,
    this.layout,
    this.presetSlot,
  });

  final Map<int, String> categories;
  final StoreLayout? layout;
  final String? presetSlot;

  @override
  State<NewProductFormScreen> createState() => _NewProductFormScreenState();
}

class _NewProductFormScreenState extends State<NewProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '10');
  final _brand = TextEditingController();
  final _description = TextEditingController();
  final _sku = TextEditingController();
  int? _categoryId;
  bool _categoryMissing = false;
  String _unit = productUnits.first;
  late String? _slot = widget.presetSlot;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    _brand.dispose();
    _description.dispose();
    _sku.dispose();
    super.dispose();
  }

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _number(String? value) {
    final parsed = _parse(value ?? '');
    return parsed == null || parsed < 0 ? 'Escribe un número válido' : null;
  }

  Future<void> _chooseSlot() async {
    final layout = widget.layout;
    if (layout == null) return;
    final slot = await showFreeSlotPicker(context, layout: layout);
    if (slot != null && mounted) setState(() => _slot = slot);
  }

  void _submit() {
    final valid = _formKey.currentState!.validate();
    setState(() => _categoryMissing = _categoryId == null);
    if (!valid || _categoryId == null) return;
    Navigator.pop(
      context,
      NewCatalogProduct(
        name: _name.text.trim(),
        price: _parse(_price.text)!,
        stock: _parse(_stock.text)!,
        categoryId: _categoryId!,
        unitOfMeasure: _unit,
        brand: _brand.text,
        description: _description.text,
        sku: _sku.text,
        slotCode: _slot,
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        color: AppTheme.ink,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final canPlace = layout != null && layout.freeCount > 0;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: Row(
                  children: [
                    SmSquareButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Crear producto',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  children: [
                    SmTextField(
                      label: 'Nombre',
                      controller: _name,
                      hintText: 'Ej. Fideo canelón 400 g',
                      maxLength: 150,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
                    ),
                    const SizedBox(height: 16),
                    _label('Categoría'),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final entry in widget.categories.entries)
                          PillChip(
                            label: entry.value,
                            selected: _categoryId == entry.key,
                            onTap: () => setState(() {
                              _categoryId = entry.key;
                              _categoryMissing = false;
                            }),
                          ),
                      ],
                    ),
                    if (_categoryMissing)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Elige una categoría',
                          style: TextStyle(
                            color: AppTheme.danger,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SmTextField(
                            label: 'Precio (Bs)',
                            controller: _price,
                            hintText: '0,00',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _number,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SmTextField(
                            label: 'Stock inicial',
                            controller: _stock,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _label('Unidad de medida'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final unit in productUnits)
                          PillChip(
                            label: unit,
                            selected: _unit == unit,
                            onTap: () => setState(() => _unit = unit),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SmTextField(
                      label: 'Marca (opcional)',
                      controller: _brand,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    SmTextField(
                      label: 'Descripción (opcional)',
                      controller: _description,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    SmTextField(
                      label: 'Código SKU (opcional)',
                      controller: _sku,
                      hintText: 'Se genera solo si lo dejas vacío',
                      maxLength: 100,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 20),
                    _label('Ubicación'),
                    _PlaceOption(
                      icon: Icons.inventory_2_outlined,
                      title: 'Solo en el inventario',
                      subtitle: 'Lo pondrás en un estante más tarde',
                      selected: _slot == null,
                      onTap: () => setState(() => _slot = null),
                    ),
                    const SizedBox(height: 10),
                    _PlaceOption(
                      icon: Icons.shelves,
                      title: _slot == null
                          ? 'En un espacio libre del plano'
                          : layout?.placeOf(_slot!) ?? _slot!,
                      subtitle: _slot == null
                          ? canPlace
                                ? '${layout.freeCount} espacios libres'
                                : 'No hay espacios libres ahora'
                          : 'Toca para elegir otro espacio',
                      selected: _slot != null,
                      onTap: canPlace ? _chooseSlot : null,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: SmPrimaryButton(
                  label: 'Crear producto',
                  icon: Icons.check_rounded,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceOption extends StatelessWidget {
  const _PlaceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusL);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppTheme.tint : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppTheme.green : AppTheme.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: onTap == null ? AppTheme.muted : AppTheme.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: onTap == null ? AppTheme.muted : AppTheme.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppTheme.green : AppTheme.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
