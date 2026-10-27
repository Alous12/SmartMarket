import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          title: const Text('Panel del trabajador'),
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
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add_box_outlined), text: 'Agregar producto'),
              Tab(icon: Icon(Icons.swap_horiz), text: 'Cambiar de lugar'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_AddProductPlaceholder(), _MoveProductTab()],
        ),
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _AddProductPlaceholder extends StatelessWidget {
  const _AddProductPlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

String? _number(String? value) =>
    double.tryParse((value ?? '').trim().replaceAll(',', '.')) == null
    ? 'Número inválido'
    : null;

double _parse(TextEditingController controller) =>
    double.parse(controller.text.trim().replaceAll(',', '.'));

class _LocationFields extends StatelessWidget {
  const _LocationFields({
    required this.sections,
    required this.sectionId,
    required this.onSectionChanged,
    required this.x,
    required this.y,
    required this.z,
    required this.shelf,
  });

  final List<SectionOption> sections;
  final int? sectionId;
  final ValueChanged<int?> onSectionChanged;
  final TextEditingController x;
  final TextEditingController y;
  final TextEditingController z;
  final TextEditingController shelf;

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

    return Column(
      children: [
        DropdownButtonFormField<int>(
          initialValue: sectionId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sección'),
          items: [
            for (final section in sections)
              DropdownMenuItem(value: section.id, child: Text(section.label)),
          ],
          onChanged: onSectionChanged,
          validator: (value) => value == null ? 'Selecciona una sección' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            coordinate('X', x),
            const SizedBox(width: 8),
            coordinate('Y', y),
            const SizedBox(width: 8),
            coordinate('Z', z),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: shelf,
          decoration: const InputDecoration(labelText: 'Estante (opcional)'),
        ),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(staffProductsProvider),
      ),
      data: (items) => RefreshIndicator(
        onRefresh: () => ref.refresh(staffProductsProvider.future),
        child: ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final p = items[index];
            return ListTile(
              title: Text(p.name),
              subtitle: Text(
                '${p.sku} · ${p.branchName == null ? '' : '${p.branchName} · '}${p.sectionName ?? 'Sin ubicación'}'
                '${p.shelf == null ? '' : ' · ${p.shelf}'}',
              ),
              trailing: const Icon(Icons.edit_location_alt_outlined),
              onTap: options.hasValue
                  ? () => _move(context, ref, p, options.requireValue.sections)
                  : null,
            );
          },
        ),
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
