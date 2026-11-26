import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/format/location.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sm_buttons.dart';
import '../../../../core/widgets/sm_text_field.dart';
import '../../domain/entities/store_model.dart';

enum SlotAction { pickUp, drop, edit, remove, create, finish }

/// Acción elegida en la hoja de un espacio. En [SlotAction.edit] puede traer
/// el precio y el stock ya editados en la hoja.
class SlotChoice {
  const SlotChoice(this.action, {this.form});

  final SlotAction action;
  final ProductFormResult? form;
}

/// «Pastas · Estante E01-09 · espacio 3» para un espacio del modelo.
String slotPlace(StoreProduct slot) {
  final number = slotNumber(slot.slotId.isEmpty ? slot.id : slot.slotId);
  return [
    placeLabel(
      section: slot.section,
      shelf: slot.shelf,
      fallback: slot.category,
    ),
    if (number != null) 'espacio $number',
  ].where((part) => part.isNotEmpty).join(' · ');
}

/// Hoja que aparece cuando el avatar llega a un espacio de la estantería.
/// [product] es null si el espacio está libre; [carrying] es el producto en mano.
Future<SlotChoice?> showSlotActions(
  BuildContext context, {
  StoreProduct? product,
  StoreProduct? carrying,
  StoreProduct? slot,
}) {
  return showModalBottomSheet<SlotChoice>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    sheetAnimationStyle: AnimationStyle(
      curve: Curves.easeOutCubic,
      duration: AppTheme.motion(context, AppTheme.slow),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: product == null
              ? _FreeSlot(
                  carrying: carrying,
                  place: slot == null ? '' : slotPlace(slot),
                )
              : _OccupiedSlot(product: product, carrying: carrying),
        ),
      ),
    ),
  );
}

void _choose(BuildContext context, SlotChoice choice) {
  if (choice.action == SlotAction.drop) HapticFeedback.selectionClick();
  Navigator.pop(context, choice);
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.muted, fontSize: 16),
          ),
      ],
    );
  }
}

/// Caja ocupada: edición rápida de precio y stock, recoger o quitar.
class _OccupiedSlot extends StatefulWidget {
  const _OccupiedSlot({required this.product, required this.carrying});

  final StoreProduct product;
  final StoreProduct? carrying;

  @override
  State<_OccupiedSlot> createState() => _OccupiedSlotState();
}

class _OccupiedSlotState extends State<_OccupiedSlot> {
  final _formKey = GlobalKey<FormState>();
  late final _price = TextEditingController(
    text: widget.product.price == null
        ? ''
        : widget.product.price!.toStringAsFixed(2).replaceFirst('.', ','),
  );
  late double _stock = widget.product.stock ?? 0;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    _choose(
      context,
      SlotChoice(
        SlotAction.edit,
        form: ProductFormResult(
          name: widget.product.name,
          price: double.parse(_price.text.trim().replaceAll(',', '.')),
          stock: _stock,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final carried = widget.carrying;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTitle(title: product.name, subtitle: slotPlace(product)),
        const SizedBox(height: 18),
        if (carried != null)
          SmPrimaryButton(
            label: 'Intercambiar con «${carried.name}»',
            icon: Icons.swap_horiz_rounded,
            onPressed: () =>
                _choose(context, const SlotChoice(SlotAction.drop)),
          )
        else ...[
          Form(
            key: _formKey,
            child: Row(
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
                  child: _StockStepper(
                    value: _stock,
                    onChanged: (value) => setState(() => _stock = value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SmPrimaryButton(label: 'Guardar precio y stock', onPressed: _save),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          _ActionRow(
            icon: Icons.open_with_rounded,
            label: 'Recoger para moverlo',
            subtitle: 'Luego toca otro espacio o intercámbialo',
            onTap: () => _choose(context, const SlotChoice(SlotAction.pickUp)),
          ),
          _ActionRow(
            icon: Icons.delete_outline_rounded,
            label: 'Quitar de la sucursal',
            subtitle: 'Se eliminará su stock y ubicación',
            danger: true,
            onTap: () => _choose(context, const SlotChoice(SlotAction.remove)),
          ),
        ],
      ],
    );
  }
}

/// Stock con botones − y + en una caja como la del campo de precio.
class _StockStepper extends StatelessWidget {
  const _StockStepper({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = value % 1 == 0
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Stock',
          style: TextStyle(
            color: AppTheme.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(color: const Color(0xFFDDE1D8), width: 1.5),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Restar uno',
                onPressed: value <= 0
                    ? null
                    : () => onChanged((value - 1).clamp(0, double.infinity)),
                icon: const Icon(Icons.remove_rounded, color: AppTheme.ink),
              ),
              Expanded(
                child: Semantics(
                  label: 'Stock',
                  value: text,
                  liveRegion: true,
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sumar uno',
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add_rounded, color: AppTheme.ink),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Espacio libre: dejar lo que se lleva en la mano o agregar un producto.
class _FreeSlot extends StatelessWidget {
  const _FreeSlot({required this.carrying, required this.place});

  final StoreProduct? carrying;
  final String place;

  @override
  Widget build(BuildContext context) {
    final carried = carrying;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTitle(title: 'Espacio libre', subtitle: place),
        const SizedBox(height: 18),
        if (carried != null)
          SmPrimaryButton(
            label: 'Dejar «${carried.name}» aquí',
            icon: Icons.arrow_downward_rounded,
            onPressed: () =>
                _choose(context, const SlotChoice(SlotAction.drop)),
          )
        else
          SmPrimaryButton(
            label: 'Agregar producto nuevo',
            icon: Icons.add_rounded,
            onPressed: () =>
                _choose(context, const SlotChoice(SlotAction.create)),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    _choose(context, const SlotChoice(SlotAction.finish)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(58),
                ),
                child: const Text('Terminar edición'),
              ),
            ),
            if (carried != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      _choose(context, const SlotChoice(SlotAction.create)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                  ),
                  child: const Text('Producto nuevo'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Acción con icono en un cuadro tintado y su explicación.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppTheme.danger : AppTheme.green;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusS),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: danger ? AppTheme.dangerTint : AppTheme.tint,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: danger ? AppTheme.danger : AppTheme.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 15),
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

String? _number(String? value) {
  final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  return parsed == null || parsed < 0 ? 'Número inválido' : null;
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

/// Formulario de producto. Con [categories] abre «Nuevo producto» a pantalla
/// completa; sin ellas, la edición de nombre, precio y stock en una hoja.
Future<ProductFormResult?> showProductForm(
  BuildContext context, {
  required String title,
  String name = '',
  double? price,
  double? stock,
  Map<int, String>? categories,
  String? location,
}) {
  if (categories != null) {
    return Navigator.of(context, rootNavigator: true).push<ProductFormResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _NewProductScreen(
          title: title,
          categories: categories,
          location: location ?? '',
        ),
      ),
    );
  }
  return showModalBottomSheet<ProductFormResult>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) =>
        _EditForm(title: title, name: name, price: price, stock: stock),
  );
}

/// «Nuevo producto»: ubicación elegida en el mapa, nombre, categoría en chips,
/// precio y stock inicial.
class _NewProductScreen extends StatefulWidget {
  const _NewProductScreen({
    required this.title,
    required this.categories,
    required this.location,
  });

  final String title;
  final Map<int, String> categories;
  final String location;

  @override
  State<_NewProductScreen> createState() => _NewProductScreenState();
}

class _NewProductScreenState extends State<_NewProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '10');
  int? _categoryId;
  bool _categoryMissing = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  void _submit() {
    final valid = _formKey.currentState!.validate();
    setState(() => _categoryMissing = _categoryId == null);
    if (!valid || _categoryId == null) return;
    Navigator.pop(
      context,
      ProductFormResult(
        name: _name.text.trim(),
        price: double.parse(_price.text.trim().replaceAll(',', '.')),
        stock: double.parse(_stock.text.trim().replaceAll(',', '.')),
        categoryId: _categoryId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      widget.title == 'Producto nuevo'
                          ? 'Nuevo producto'
                          : widget.title,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  children: [
                    if (widget.location.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.night,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXL,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.lime,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusM,
                                ),
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ubicación elegida en el mapa',
                                    style: TextStyle(
                                      color: AppTheme.onNightMuted,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    widget.location,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.lime,
                              ),
                              child: const Text(
                                'Cambiar',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppTheme.lime,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    SmTextField(
                      label: 'Nombre',
                      controller: _name,
                      hintText: 'Ej. Fideo canelón 400 g',
                      maxLength: 150,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Categoría',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: SmPrimaryButton(
                  label: 'Agregar producto',
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

/// Edición de nombre, precio y stock en una hoja.
class _EditForm extends StatefulWidget {
  const _EditForm({
    required this.title,
    required this.name,
    this.price,
    this.stock,
  });

  final String title;
  final String name;
  final double? price;
  final double? stock;

  @override
  State<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  late final _price = TextEditingController(
    text: widget.price == null
        ? ''
        : widget.price!.toStringAsFixed(2).replaceFirst('.', ','),
  );
  late final _stock = TextEditingController(
    text: switch (widget.stock) {
      null => '',
      final stock => stock.toStringAsFixed(stock % 1 == 0 ? 0 : 2),
    },
  );

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ProductFormResult(
        name: _name.text.trim(),
        price: double.parse(_price.text.trim().replaceAll(',', '.')),
        stock: double.parse(_stock.text.trim().replaceAll(',', '.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetTitle(title: widget.title, subtitle: ''),
                const SizedBox(height: 16),
                SmTextField(
                  label: 'Nombre',
                  controller: _name,
                  maxLength: 150,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SmTextField(
                        label: 'Precio (Bs)',
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _number,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SmTextField(
                        label: 'Stock',
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
                SmPrimaryButton(label: 'Guardar', onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
