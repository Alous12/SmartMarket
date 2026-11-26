import 'package:flutter/material.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sm_buttons.dart';
import '../../../../core/widgets/sm_search_field.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/store_model.dart';
import '../../domain/services/store_layout.dart';

/// Lo que el admin eligió hacer con un espacio del plano.
enum SlotSheetAction {
  /// Elegir otro espacio (de cualquier pasillo) e intercambiarlos.
  swap,

  /// Poner en su lugar un producto del inventario.
  replaceFromInventory,

  /// Sacarlo del estante: queda en el inventario con su stock.
  sendToInventory,
  edit,
  remove,

  /// Espacio libre: poner un producto del inventario.
  placeFromInventory,

  /// Espacio libre: crear un producto nuevo aquí.
  createHere,
}

/// Hoja de un espacio: el producto que lo ocupa y lo que se puede hacer.
Future<SlotSheetAction?> showSlotSheet(
  BuildContext context, {
  required LayoutSlot slot,
  required String name,
  required String place,
  required int unplacedCount,
}) {
  return showModalBottomSheet<SlotSheetAction>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    sheetAnimationStyle: AnimationStyle(
      curve: Curves.easeOutCubic,
      duration: AppTheme.motion(context, AppTheme.slow),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: slot.product == null
            ? _FreeSlotActions(place: place, unplacedCount: unplacedCount)
            : _OccupiedSlotActions(
                product: slot.product!,
                name: name,
                place: place,
              ),
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.place});

  final String title;
  final String place;

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
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: AppTheme.muted,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                place,
                style: const TextStyle(color: AppTheme.muted, fontSize: 15),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OccupiedSlotActions extends StatelessWidget {
  const _OccupiedSlotActions({
    required this.product,
    required this.name,
    required this.place,
  });

  final StoreProduct product;
  final String name;
  final String place;

  @override
  Widget build(BuildContext context) {
    final stock = product.stock;
    void choose(SlotSheetAction action) => Navigator.pop(context, action);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(title: name, place: place),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Fact(
                label: 'Precio',
                value: product.price == null ? '—' : formatBs(product.price!),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Fact(
                label: 'Stock',
                value: stock == null ? '—' : '${compactNumber(stock)} u.',
                tone: stock == null
                    ? null
                    : stock <= 0
                    ? StatusTone.danger
                    : stock <= 5
                    ? StatusTone.warning
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Fact(
                label: 'Categoría',
                value: product.category.isEmpty ? '—' : product.category,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SmPrimaryButton(
          label: 'Intercambiar con otro producto',
          icon: Icons.swap_horiz_rounded,
          onPressed: () => choose(SlotSheetAction.swap),
        ),
        const SizedBox(height: 6),
        _ActionTile(
          icon: Icons.inventory_2_outlined,
          label: 'Reemplazar con uno del inventario',
          subtitle: '"$name" pasará al inventario',
          onTap: () => choose(SlotSheetAction.replaceFromInventory),
        ),
        _ActionTile(
          icon: Icons.edit_outlined,
          label: 'Editar nombre, precio y stock',
          subtitle: 'Se guarda en la base de datos',
          onTap: () => choose(SlotSheetAction.edit),
        ),
        _ActionTile(
          icon: Icons.move_to_inbox_outlined,
          label: 'Enviar al inventario',
          subtitle: 'Libera el espacio y conserva el stock',
          onTap: () => choose(SlotSheetAction.sendToInventory),
        ),
        _ActionTile(
          icon: Icons.delete_outline_rounded,
          label: 'Quitar de la sucursal',
          subtitle: 'Se eliminará su stock y ubicación',
          danger: true,
          onTap: () => choose(SlotSheetAction.remove),
        ),
      ],
    );
  }
}

class _FreeSlotActions extends StatelessWidget {
  const _FreeSlotActions({required this.place, required this.unplacedCount});

  final String place;
  final int unplacedCount;

  @override
  Widget build(BuildContext context) {
    void choose(SlotSheetAction action) => Navigator.pop(context, action);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(title: 'Espacio libre', place: place),
        const SizedBox(height: 18),
        SmPrimaryButton(
          label: 'Poner un producto del inventario',
          icon: Icons.inventory_2_outlined,
          onPressed: () => choose(SlotSheetAction.placeFromInventory),
        ),
        if (unplacedCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              '$unplacedCount ${unplacedCount == 1 ? 'producto espera' : 'productos esperan'} '
              'en el inventario, sin estante.',
              style: const TextStyle(color: AppTheme.muted, fontSize: 14),
            ),
          ),
        const SizedBox(height: 6),
        _ActionTile(
          icon: Icons.add_box_outlined,
          label: 'Crear un producto nuevo aquí',
          subtitle: 'Con su categoría, precio y stock inicial',
          onTap: () => choose(SlotSheetAction.createHere),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      StatusTone.danger => (AppTheme.dangerTint, AppTheme.danger),
      StatusTone.warning => (AppTheme.warningTint, AppTheme.warning),
      _ => (AppTheme.background, AppTheme.ink),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: danger ? AppTheme.dangerTint : AppTheme.tint,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: danger ? AppTheme.danger : AppTheme.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

/// Inventario de la sucursal para elegir un producto. Muestra primero los que
/// no tienen estante; con «Todos» también los que ya están en uno (elegirlos
/// los mueve). [placeOf] da su ubicación, o null si no tiene estante.
Future<StoreProduct?> showInventoryPicker(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<StoreProduct> unplaced,
  required List<StoreProduct> placed,
  required String? Function(StoreProduct product) placeOf,
  required String Function(StoreProduct product) nameOf,
  int? excludeDbId,
}) {
  return showModalBottomSheet<StoreProduct>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (context) => _InventoryPicker(
      title: title,
      subtitle: subtitle,
      unplaced: unplaced,
      placed: [
        for (final product in placed)
          if (product.dbId != excludeDbId) product,
      ],
      placeOf: placeOf,
      nameOf: nameOf,
    ),
  );
}

class _InventoryPicker extends StatefulWidget {
  const _InventoryPicker({
    required this.title,
    required this.subtitle,
    required this.unplaced,
    required this.placed,
    required this.placeOf,
    required this.nameOf,
  });

  final String title;
  final String subtitle;
  final List<StoreProduct> unplaced;
  final List<StoreProduct> placed;
  final String? Function(StoreProduct product) placeOf;
  final String Function(StoreProduct product) nameOf;

  @override
  State<_InventoryPicker> createState() => _InventoryPickerState();
}

class _InventoryPickerState extends State<_InventoryPicker> {
  late bool _onlyUnplaced = widget.unplaced.isNotEmpty;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = normalizeForSearch(_query.trim());
    final source = [
      ...widget.unplaced,
      if (!_onlyUnplaced)
        ...(widget.placed.toList()..sort(
          (a, b) => widget
              .nameOf(a)
              .toLowerCase()
              .compareTo(widget.nameOf(b).toLowerCase()),
        )),
    ];
    final visible = [
      for (final product in source)
        if (query.isEmpty ||
            normalizeForSearch(
              '${widget.nameOf(product)} ${product.category}',
            ).contains(query))
          product,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _SheetHeader(title: widget.title, place: widget.subtitle),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: SmSearchField(
                hintText: 'Buscar en el inventario',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PillChip(
                    label: 'Sin estante (${widget.unplaced.length})',
                    selected: _onlyUnplaced,
                    onTap: () => setState(() => _onlyUnplaced = true),
                  ),
                  PillChip(
                    label: 'Todos',
                    selected: !_onlyUnplaced,
                    onTap: () => setState(() => _onlyUnplaced = false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(28),
                      children: [
                        Text(
                          _onlyUnplaced && widget.unplaced.isEmpty
                              ? 'Todos los productos ya están en un estante. '
                                    'Elige «Todos» para moverlos de lugar.'
                              : 'No hay productos que coincidan.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: visible.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = visible[index];
                        return _InventoryRow(
                          name: widget.nameOf(product),
                          product: product,
                          place: widget.placeOf(product),
                          onTap: () => Navigator.pop(context, product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({
    required this.name,
    required this.product,
    required this.place,
    required this.onTap,
  });

  final String name;
  final StoreProduct product;
  final String? place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stock = product.stock;
    final radius = BorderRadius.circular(AppTheme.radiusL);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppTheme.border, width: 1.5),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (product.category.isNotEmpty) product.category,
                        if (product.price != null) formatBs(product.price!),
                        if (stock != null) '${compactNumber(stock)} u.',
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    place == null
                        ? const StatusChip(
                            label: 'Sin estante',
                            tone: StatusTone.neutral,
                            icon: Icons.inventory_2_outlined,
                          )
                        : Text(
                            place!,
                            style: const TextStyle(
                              color: AppTheme.green,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Espacios libres del plano, por pasillo, para elegir dónde va algo.
Future<String?> showFreeSlotPicker(
  BuildContext context, {
  required StoreLayout layout,
}) {
  final aisles = [
    for (final aisle in layout.aisles)
      if (aisle.freeCount > 0) aisle,
  ];
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const _SheetHeader(
            title: 'Elige un espacio libre',
            place: 'El producto quedará en ese estante',
          ),
          const SizedBox(height: 10),
          if (aisles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay espacios libres. Envía un producto al inventario '
                'para liberar uno.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 16),
              ),
            ),
          for (final aisle in aisles) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
              child: Text(
                aisle.label,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final shelf in aisle.shelves)
              for (final (index, slot) in shelf.slots.indexed)
                if (slot.isFree)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(
                      Icons.add_box_outlined,
                      color: AppTheme.green,
                    ),
                    title: Text('${shelfName(shelf.code)} · espacio ${index + 1}'),
                    onTap: () => Navigator.pop(context, slot.code),
                  ),
          ],
        ],
      ),
    ),
  );
}

/// Pide confirmar un cambio en los estantes.
Future<bool> confirmLayoutChange(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: Colors.white,
                )
              : null,
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Texto sin mayúsculas ni tildes para buscar.
String normalizeForSearch(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úù]'), 'u');
