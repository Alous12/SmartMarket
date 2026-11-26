import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/store_model.dart';

/// Hoja «Elige tus productos» para armar la ruta. Devuelve los ids de caja
/// elegidos (vacío para quitar la ruta) o null si se cierra.
Future<List<String>?> showRoutePicker(
  BuildContext context, {
  required List<StoreProduct> products,
  required List<String> selected,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    sheetAnimationStyle: AnimationStyle(
      curve: Curves.easeOutCubic,
      duration: AppTheme.motion(context, AppTheme.slow),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      minChildSize: 0.5,
      maxChildSize: 0.94,
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

  void _toggle(StoreProduct product) => setState(() {
    if (!_selected.remove(product.id)) _selected.add(product.id);
  });

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
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      borderSide: const BorderSide(color: Color(0xFFDDE1D8), width: 1.5),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Elige tus productos',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: _selected.isEmpty ? 0.4 : 1,
                duration: AppTheme.motion(context, AppTheme.fast),
                child: TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => setState(_selected.clear),
                  child: const Text('Limpiar'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 17, color: AppTheme.ink),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o categoría',
              hintStyle: const TextStyle(color: AppTheme.muted, fontSize: 17),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 12, right: 4),
                child: Icon(Icons.search_rounded, color: AppTheme.muted),
              ),
              filled: true,
              fillColor: AppTheme.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: const BorderSide(color: AppTheme.green, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            controller: widget.controller,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final product = visible[index];
              final enabled = _selectable(product);
              return _ProductRow(
                product: product,
                checked: _selected.contains(product.id),
                enabled: enabled,
                onTap: enabled ? () => _toggle(product) : null,
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _selected.toList()),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
              ),
              child: AnimatedSwitcher(
                duration: AppTheme.motion(context, AppTheme.fast),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.9, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  _selected.isEmpty
                      ? 'Quitar ruta'
                      : 'Crear ruta (${_selected.length})',
                  key: ValueKey(_selected.length),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.checked,
    required this.enabled,
    required this.onTap,
  });

  final StoreProduct product;
  final bool checked;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final duration = AppTheme.motion(context, AppTheme.fast);
    return Semantics(
      checked: checked,
      enabled: enabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: duration,
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: checked ? AppTheme.green : Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: checked
                          ? AppTheme.green
                          : enabled
                          ? const Color(0xFFCFD7C9)
                          : AppTheme.border,
                      width: 2.5,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: duration,
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: checked
                        ? const Icon(
                            Icons.check_rounded,
                            key: ValueKey('checked'),
                            size: 20,
                            color: Colors.white,
                          )
                        : const SizedBox.shrink(key: ValueKey('empty')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          color: enabled
                              ? AppTheme.ink
                              : AppTheme.muted.withValues(alpha: 0.7),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (product.category.isNotEmpty)
                        Text(
                          product.category,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 15,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!enabled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Agotado',
                      style: TextStyle(
                        color: AppTheme.danger,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
