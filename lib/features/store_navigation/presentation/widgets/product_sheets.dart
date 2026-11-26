import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/format/location.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/horizontal_scroll_row.dart';
import '../../../../core/widgets/sm_buttons.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/store_model.dart';
import '../providers/store_model_provider.dart';
import 'inventory_charts.dart';
import 'store_labels.dart';

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
    sheetAnimationStyle: AnimationStyle(
      curve: Curves.easeOutCubic,
      duration: AppTheme.motion(context, AppTheme.slow),
    ),
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
          Text('Nombre del producto', style: theme.textTheme.headlineSmall),
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
              helperText: 'Solo cambia en este teléfono.',
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

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úù]'), 'u');

/// Dónde está el producto: estante, sección o categoría.
String productPlace(StoreProduct product) => product.shelf != null
    ? shelfLabel(product.shelf!)
    : placeLabel(section: product.section, fallback: product.category);

/// Productos de la sucursal: catálogo en cuadrícula para el cliente; tablero
/// de inventario con lo que requiere atención para el admin.
class ProductListView extends ConsumerStatefulWidget {
  const ProductListView({
    super.key,
    required this.store,
    required this.products,
    required this.onSelected,
    required this.onRename,
    this.admin = false,
    this.onEditStore,
    this.onAskAssistant,
    this.onOpenUsers,
  });

  final Supermarket store;
  final List<StoreProduct> products;
  final ValueChanged<StoreProduct> onSelected;
  final ValueChanged<StoreProduct> onRename;
  final bool admin;

  /// Admin: abrir el mapa en «Editar tienda».
  final VoidCallback? onEditStore;

  /// Admin: «Preguntar a la IA».
  final VoidCallback? onAskAssistant;

  /// Admin: gestión de usuarios.
  final VoidCallback? onOpenUsers;

  @override
  ConsumerState<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends ConsumerState<ProductListView> {
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(productNamesProvider).value ?? const {};
    final query = _normalize(_query.trim());
    bool matches(StoreProduct product) {
      if (query.isEmpty) return true;
      final name = names[product.id] ?? product.name;
      return _normalize(
        '$name ${product.category} ${product.id}',
      ).contains(query);
    }

    return widget.admin
        ? _buildAdmin(context, names, matches)
        : _buildClient(context, names, matches);
  }

  Widget _search(String hint) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: _SearchBox(
      hint: hint,
      onChanged: (value) => setState(() => _query = value),
    ),
  );

  Widget _buildClient(
    BuildContext context,
    Map<String, String> names,
    bool Function(StoreProduct) matches,
  ) {
    final categories =
        widget.products
            .map((product) => product.category)
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final visible = widget.products
        .where((p) => _category == null || p.category == _category)
        .where(matches)
        .toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _search('Buscar en ${widget.store.displayName}'),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 76,
            child: HorizontalScrollRow(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              children: [
                PillChip(
                  label: 'Todo',
                  selected: _category == null,
                  onTap: () => setState(() => _category = null),
                ),
                for (final category in categories) ...[
                  const SizedBox(width: 10),
                  PillChip(
                    label: category,
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No hay productos que coincidan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 16),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              mainAxisExtent: 250,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final product = visible[index];
              return StaggeredEntrance(
                index: index,
                child: _ProductCard(
                  product: product,
                  name: names[product.id] ?? product.name,
                  onShow: () => widget.onSelected(product),
                  onRename: () => widget.onRename(product),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdmin(
    BuildContext context,
    Map<String, String> names,
    bool Function(StoreProduct) matches,
  ) {
    final stocked = widget.products.where((p) => p.stock != null).toList();
    final searching = _query.trim().isNotEmpty;
    final attention = searching
        ? const <StoreProduct>[]
        : (stocked.where((p) => p.stock! <= 5).toList()
            ..sort((a, b) => a.stock!.compareTo(b.stock!)));
    // Cada producto aparece una sola vez: lo urgente arriba, el resto abajo.
    final all =
        widget.products
            .where(matches)
            .where((p) => !attention.contains(p))
            .toList()
          ..sort(
            (a, b) => (names[a.id] ?? a.name).toLowerCase().compareTo(
              (names[b.id] ?? b.name).toLowerCase(),
            ),
          );
    Widget heading(String title, String? subtitle, {Widget? trailing}) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
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
              ?trailing,
            ],
          ),
        );
    SliverPadding list(List<StoreProduct> rows) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      sliver: SliverList.separated(
        itemCount: rows.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => StaggeredEntrance(
          index: index,
          child: _AdminProductRow(
            product: rows[index],
            name: names[rows[index].id] ?? rows[index].name,
            onTap: () => widget.onSelected(rows[index]),
            onRename: () => widget.onRename(rows[index]),
          ),
        ),
      ),
    );
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _AdminHeader(
                  store: widget.store,
                  onOpenUsers: widget.onOpenUsers,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: _InventorySummary(
                    products: widget.products,
                    stocked: stocked,
                  ),
                ),
              ),
              if (!searching) ...[
                SliverToBoxAdapter(
                  child: heading(
                    'Requieren atención',
                    'Prioridad de reposición',
                    trailing: widget.onAskAssistant == null
                        ? null
                        : TextButton(
                            onPressed: widget.onAskAssistant,
                            child: const Text(
                              'Preguntar a la IA',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                decorationColor: AppTheme.green,
                              ),
                            ),
                          ),
                  ),
                ),
                if (attention.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        'Todo tiene stock suficiente.',
                        style: TextStyle(color: AppTheme.muted, fontSize: 16),
                      ),
                    ),
                  )
                else
                  list(attention),
              ],
              if (stocked.isNotEmpty && !searching) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    child: ChartCard(
                      icon: Icons.bar_chart_rounded,
                      title: 'Unidades por categoría',
                      subtitle: 'Stock disponible en la sucursal',
                      child: StockByCategoryChart(products: widget.products),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: ChartCard(
                      icon: Icons.pie_chart_outline_rounded,
                      title: 'Valor del inventario',
                      subtitle: 'Precio × stock, por categoría',
                      child: ValueByCategoryChart(products: widget.products),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              // Con clave: al buscar se ocultan las secciones de arriba y el
              // campo debe conservar el foco y el texto.
              SliverToBoxAdapter(
                key: const ValueKey('admin-search'),
                child: _search('Buscar producto o SKU'),
              ),
              SliverToBoxAdapter(
                child: heading(
                  searching ? 'Resultados' : 'Con stock suficiente',
                  '${all.length} ${all.length == 1 ? 'producto' : 'productos'}',
                ),
              ),
              list(all),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],
          ),
        ),
        if (widget.onEditStore != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            child: SmPrimaryButton(
              label: 'Editar tienda en el mapa',
              icon: Icons.view_in_ar_outlined,
              onPressed: widget.onEditStore,
            ),
          ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      borderSide: const BorderSide(color: Color(0xFFDDE1D8), width: 1.5),
    );
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 17, color: AppTheme.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.muted, fontSize: 17),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 14, right: 6),
          child: Icon(Icons.search_rounded, color: AppTheme.muted),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppTheme.green, width: 2),
        ),
      ),
    );
  }
}

/// Tarjeta del catálogo: foto, nombre, estante, precio y botón para ir al
/// mapa. Mantener presionado permite renombrarla.
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.name,
    required this.onShow,
    required this.onRename,
  });

  final StoreProduct product;
  final String name;
  final VoidCallback onShow;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stock != null && product.stock! <= 0;
    final radius = BorderRadius.circular(AppTheme.radiusXL);
    return Semantics(
      onLongPressHint: 'Renombrar',
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppTheme.border, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onShow,
          onLongPress: onRename,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.track,
                      borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    ),
                    child: Stack(
                      children: [
                        const Center(
                          child: Icon(
                            Icons.shopping_basket_outlined,
                            size: 34,
                            color: Color(0xFF9AA095),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _PencilButton(onPressed: onRename),
                        ),
                        if (outOfStock)
                          const Positioned(
                            left: 8,
                            top: 8,
                            child: StatusChip(
                              label: 'Agotado',
                              tone: StatusTone.danger,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  productPlace(product),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.price == null ? '' : formatBs(product.price!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Ver en el mapa',
                      child: Material(
                        color: AppTheme.lime,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          onTap: onShow,
                          child: const SizedBox(
                            width: 52,
                            height: 52,
                            child: Icon(
                              Icons.near_me_outlined,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cabecera `night` del admin: sucursal y acceso a usuarios.
class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.store, required this.onOpenUsers});

  final Supermarket store;
  final VoidCallback? onOpenUsers;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.night,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ADMINISTRADOR',
                      style: TextStyle(
                        color: AppTheme.lime,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      store.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (onOpenUsers != null)
                SmSquareButton(
                  icon: Icons.group_outlined,
                  tooltip: 'Usuarios',
                  dark: true,
                  onPressed: onOpenUsers,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Resumen del inventario»: valor total y los seis indicadores en un solo
/// recuadro, sin desplazamiento (3 columnas en teléfono, 6 en pantallas anchas).
class _InventorySummary extends StatelessWidget {
  const _InventorySummary({required this.products, required this.stocked});

  final List<StoreProduct> products;
  final List<StoreProduct> stocked;

  @override
  Widget build(BuildContext context) {
    final low = stocked.where((p) => p.stock! > 0 && p.stock! <= 5).length;
    final out = stocked.where((p) => p.stock == 0).length;
    final units = stocked.fold<double>(0, (sum, p) => sum + p.stock!);
    final value = stocked.fold<double>(
      0,
      (sum, p) => sum + (p.price ?? 0) * p.stock!,
    );
    final categories = products
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;
    final priced = products.where((p) => p.price != null).toList();
    final average = priced.isEmpty
        ? 0.0
        : priced.fold<double>(0, (sum, p) => sum + p.price!) / priced.length;
    final tiles = [
      ('${products.length}', 'Productos', false),
      (compactNumber(units), 'Unidades', false),
      ('$categories', 'Categorías', false),
      ('$low', 'Por agotarse', low > 0),
      ('$out', 'Agotados', out > 0),
      (compactNumber(average.round()), 'Precio prom.', false),
    ];
    return ChartCard(
      icon: Icons.payments_outlined,
      title: 'Resumen del inventario',
      subtitle: 'Valor total en stock',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatBs(value),
              style: const TextStyle(
                color: AppTheme.green,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (stocked.isEmpty)
            const Text(
              'El inventario detallado aún no está disponible.',
              style: TextStyle(color: AppTheme.muted, fontSize: 15),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 560 ? 6 : 3;
                const gap = 8.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final (v, label, alert) in tiles)
                      SizedBox(
                        width: width,
                        child: _SummaryTile(
                          value: v,
                          label: label,
                          alert: alert,
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.value,
    required this.label,
    required this.alert,
  });

  final String value;
  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: alert ? AppTheme.warningTint : AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: alert ? AppTheme.warning : AppTheme.ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminProductRow extends StatelessWidget {
  const _AdminProductRow({
    required this.product,
    required this.name,
    required this.onTap,
    required this.onRename,
  });

  final StoreProduct product;
  final String name;
  final VoidCallback onTap;
  final VoidCallback onRename;

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
          padding: const EdgeInsets.fromLTRB(8, 16, 14, 16),
          child: Row(
            children: [
              _PencilButton(onPressed: onRename, tinted: true),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      placeLabel(
                        section: product.category.isEmpty
                            ? product.section
                            : product.category,
                        shelf: product.shelf,
                      ),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (product.price != null)
                    Text(
                      formatBs(product.price!),
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (stock != null) ...[
                    const SizedBox(height: 6),
                    stock <= 0
                        ? const StatusChip(
                            label: 'Agotado',
                            tone: StatusTone.danger,
                          )
                        : StatusChip(
                            label: '${compactNumber(stock)} u.',
                            tone: stock <= 5
                                ? StatusTone.warning
                                : StatusTone.ok,
                          ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lápiz para cambiar el nombre visible del producto.
class _PencilButton extends StatelessWidget {
  const _PencilButton({required this.onPressed, this.tinted = false});

  final VoidCallback onPressed;

  /// Fondo tint (filas) en vez de blanco (sobre la foto).
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Renombrar',
      child: Material(
        color: tinted ? AppTheme.tint : Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.edit_outlined, size: 20, color: AppTheme.green),
          ),
        ),
      ),
    );
  }
}
