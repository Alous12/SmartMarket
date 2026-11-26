import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_or_error_state.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/staff_api.dart';
import '../providers/staff_providers.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.night,
          foregroundColor: Colors.white,
          toolbarHeight: 68,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SmartMarket',
                style: TextStyle(
                  color: AppTheme.lime,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Panel de administración',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Usuarios',
              icon: const Icon(Icons.people_outline),
              onPressed: () => context.pushNamed('users'),
            ),
            IconButton(
              tooltip: 'Mapa del supermercado',
              icon: const Icon(Icons.map_outlined),
              onPressed: () => context.pushNamed('supermarket'),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.goNamed('login');
              },
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: const TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppTheme.lime,
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppTheme.radiusS),
                  ),
                ),
                dividerColor: Colors.transparent,
                labelColor: AppTheme.ink,
                unselectedLabelColor: AppTheme.onNightMuted,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  Tab(
                    height: 44,
                    iconMargin: EdgeInsets.zero,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_box_outlined, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Agregar producto',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swap_horiz, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Cambiar de lugar',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(children: [_AddProductTab(), _MoveProductTab()]),
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _AddProductTab extends ConsumerStatefulWidget {
  const _AddProductTab();

  @override
  ConsumerState<_AddProductTab> createState() => _AddProductTabState();
}

class _AddProductTabState extends ConsumerState<_AddProductTab> {
  final _formKey = GlobalKey<FormState>();
  final _sku = TextEditingController();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _price = TextEditingController();
  final _unit = TextEditingController(text: 'unidad');
  final _stock = TextEditingController();
  final _x = TextEditingController();
  final _y = TextEditingController(text: '0');
  final _z = TextEditingController();
  final _shelf = TextEditingController();
  int? _categoryId;
  int? _sectionId;
  bool _saving = false;

  /// Coordenadas visibles: se abren solas si faltan al guardar.
  bool _advanced = false;

  @override
  void dispose() {
    for (final controller in [
      _sku,
      _name,
      _brand,
      _price,
      _unit,
      _stock,
      _x,
      _y,
      _z,
      _shelf,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Este campo es obligatorio'
      : null;

  InputDecoration _field(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint);

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    // Las coordenadas viven en «Avanzado»: si faltan, se muestran.
    if ([_x, _y, _z].any((c) => _number(c.text) != null) && !_advanced) {
      setState(() => _advanced = true);
    }
    if (!valid || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(staffApiProvider)
          .createProduct(
            ProductDraft(
              sku: _sku.text.trim(),
              name: _name.text.trim(),
              brand: _brand.text.trim(),
              price: _parse(_price),
              unitOfMeasure: _unit.text.trim(),
              categoryId: _categoryId!,
              stock: _parse(_stock),
              location: LocationDraft(
                sectionId: _sectionId!,
                x: _parse(_x),
                y: _parse(_y),
                z: _parse(_z),
                shelf: _shelf.text.trim(),
              ),
            ),
          );
      ref.invalidate(staffProductsProvider);
      if (!mounted) return;
      _formKey.currentState!.reset();
      _unit.text = 'unidad';
      _y.text = '0';
      setState(() {
        _categoryId = null;
        _sectionId = null;
      });
      _showMessage(context, 'Producto agregado correctamente.');
    } on Object catch (error) {
      if (mounted) _showMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(staffOptionsProvider);
    return options.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.green)),
      error: (error, _) => EmptyOrErrorState(
        title: error.toString(),
        onRetry: () => ref.invalidate(staffOptionsProvider),
      ),
      data: (options) => Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  const _AdminIntro(
                    icon: Icons.inventory_2_outlined,
                    title: 'Inventario de la sucursal',
                    subtitle:
                        'Agrega productos con su ubicación para que aparezcan en el mapa y en las rutas.',
                  ),
                  const SizedBox(height: 12),
                  _FormCard(
                    label: 'Producto',
                    children: [
                      TextFormField(
                        controller: _sku,
                        decoration: _field('SKU'),
                        enabled: !_saving,
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _name,
                        decoration: _field('Nombre del producto'),
                        textCapitalization: TextCapitalization.words,
                        enabled: !_saving,
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _brand,
                        decoration: _field('Marca (opcional)'),
                        enabled: !_saving,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _categoryId,
                        isExpanded: true,
                        decoration: _field('Categoría'),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        items: [
                          for (final category in options.categories)
                            DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _categoryId = value),
                        validator: (value) =>
                            value == null ? 'Selecciona una categoría' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _FormCard(
                    label: 'Precio y stock',
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _price,
                              decoration: _field('Precio'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              enabled: !_saving,
                              validator: _number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _stock,
                              decoration: _field('Stock'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              enabled: !_saving,
                              validator: _number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _unit,
                        decoration: _field('Unidad'),
                        enabled: !_saving,
                        validator: _required,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _FormCard(
                    label: 'Ubicación en el supermercado',
                    children: [
                      _LocationFields(
                        sections: options.sections,
                        sectionId: _sectionId,
                        onSectionChanged: (value) =>
                            setState(() => _sectionId = value),
                        x: _x,
                        y: _y,
                        z: _z,
                        shelf: _shelf,
                        advanced: _advanced,
                        onAdvancedChanged: (value) =>
                            setState(() => _advanced = value),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppTheme.buttonHeight),
                    ),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.ink,
                            ),
                          )
                        : const Icon(Icons.add_circle_outline),
                    label: Text(_saving ? 'Guardando…' : 'Agregar producto'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _number(String? value) =>
    double.tryParse((value ?? '').trim().replaceAll(',', '.')) == null
    ? 'Número inválido'
    : null;

double _parse(TextEditingController controller) =>
    double.parse(controller.text.trim().replaceAll(',', '.'));

/// Tarjeta de un grupo del formulario con su rótulo.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(label),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LocationFields extends StatelessWidget {
  const _LocationFields({
    required this.sections,
    required this.sectionId,
    required this.onSectionChanged,
    required this.x,
    required this.y,
    required this.z,
    required this.shelf,
    this.advanced,
    this.onAdvancedChanged,
  });

  final List<SectionOption> sections;
  final int? sectionId;
  final ValueChanged<int?> onSectionChanged;
  final TextEditingController x;
  final TextEditingController y;
  final TextEditingController z;
  final TextEditingController shelf;

  /// Con valor, las coordenadas van en una sección plegable «Avanzado».
  final bool? advanced;
  final ValueChanged<bool>? onAdvancedChanged;

  @override
  Widget build(BuildContext context) {
    Widget coordinate(String label, TextEditingController controller) =>
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(labelText: label),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            validator: _number,
          ),
        );

    final coordinates = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        coordinate('X', x),
        const SizedBox(width: 8),
        coordinate('Y', y),
        const SizedBox(width: 8),
        coordinate('Z', z),
      ],
    );
    final open = advanced;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          initialValue: sectionId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sección'),
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          items: [
            for (final section in sections)
              DropdownMenuItem(value: section.id, child: Text(section.label)),
          ],
          onChanged: onSectionChanged,
          validator: (value) => value == null ? 'Selecciona una sección' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: shelf,
          decoration: const InputDecoration(labelText: 'Estante (opcional)'),
        ),
        const SizedBox(height: 12),
        if (open == null)
          coordinates
        else ...[
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            onTap: () => onAdvancedChanged?.call(!open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 20, color: AppTheme.green),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Avanzado',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: AppTheme.motion(context, AppTheme.fast),
                    child: const Icon(Icons.expand_more, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppTheme.motion(context, AppTheme.medium),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            // Los campos siguen montados aunque estén plegados, para validarlos.
            child: Visibility(
              visible: open,
              maintainState: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.tint,
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppTheme.green,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Para ubicarlo visualmente usa Editar tienda en el mapa',
                            style: TextStyle(
                              color: AppTheme.green,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  coordinates,
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MoveProductTab extends ConsumerWidget {
  const _MoveProductTab();

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    ProductLocation product,
    List<SectionOption> sections,
  ) async {
    final location = await showDialog<LocationDraft>(
      context: context,
      builder: (_) => _MoveDialog(product: product, sections: sections),
    );
    if (location == null) return;
    try {
      await ref.read(staffApiProvider).moveProduct(product.productId, location);
      ref.invalidate(staffProductsProvider);
      if (context.mounted) _showMessage(context, 'Ubicación actualizada.');
    } on Object catch (error) {
      if (context.mounted) _showMessage(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(staffProductsProvider);
    final options = ref.watch(staffOptionsProvider);
    return products.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.green)),
      error: (error, _) => EmptyOrErrorState(
        title: error.toString(),
        onRetry: () => ref.invalidate(staffProductsProvider),
      ),
      data: (items) => RefreshIndicator(
        color: AppTheme.green,
        onRefresh: () => ref.refresh(staffProductsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const _AdminIntro(
              icon: Icons.edit_location_alt_outlined,
              title: 'Ubicaciones del mapa',
              subtitle:
                  'Toca un producto para actualizar su sección, coordenadas o estante.',
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const EmptyOrErrorState(
                error: false,
                icon: Icons.location_off_outlined,
                title: 'Todavía no hay productos con ubicación.',
              )
            else
              for (final (index, p) in items.indexed) ...[
                StaggeredEntrance(
                  index: index,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.tint,
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppTheme.green,
                        ),
                      ),
                      title: Text(
                        p.name,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${p.sku} · ${p.branchName == null ? '' : '${p.branchName} · '}${p.sectionName ?? 'Sin ubicación'}'
                        '${p.shelf == null ? '' : ' · ${p.shelf}'}',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 13,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppTheme.muted,
                      ),
                      onTap: options.hasValue
                          ? () => _move(
                              context,
                              ref,
                              p,
                              options.requireValue.sections,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

class _AdminIntro extends StatelessWidget {
  const _AdminIntro({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.tint,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.lime,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Icon(icon, color: AppTheme.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveDialog extends StatefulWidget {
  const _MoveDialog({required this.product, required this.sections});

  final ProductLocation product;
  final List<SectionOption> sections;

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _x = TextEditingController(text: widget.product.x?.toString());
  late final _y = TextEditingController(text: widget.product.y?.toString());
  late final _z = TextEditingController(text: widget.product.z?.toString());
  late final _shelf = TextEditingController(text: widget.product.shelf);
  late int? _sectionId =
      widget.sections.any((s) => s.id == widget.product.sectionId)
      ? widget.product.sectionId
      : null;

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    _z.dispose();
    _shelf.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Mover ${widget.product.name}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: _LocationFields(
            sections: widget.sections,
            sectionId: _sectionId,
            onSectionChanged: (value) => setState(() => _sectionId = value),
            x: _x,
            y: _y,
            z: _z,
            shelf: _shelf,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              LocationDraft(
                sectionId: _sectionId!,
                x: _parse(_x),
                y: _parse(_y),
                z: _parse(_z),
                shelf: _shelf.text.trim(),
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
