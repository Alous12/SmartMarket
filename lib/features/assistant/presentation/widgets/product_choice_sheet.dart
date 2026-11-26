import 'package:flutter/material.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/format/location.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../../core/widgets/sm_buttons.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../domain/entities/recipe_availability.dart';

/// Lo que el usuario decidió en la hoja de un ingrediente.
sealed class ProductChoiceResult {
  const ProductChoiceResult();
}

class UseProduct extends ProductChoiceResult {
  const UseProduct(this.option);

  final IngredientProductOption option;
}

class SetIngredientExcluded extends ProductChoiceResult {
  const SetIngredientExcluded(this.excluded);

  final bool excluded;
}

/// Hoja «Elegir producto»: opciones del ingrediente en una sucursal como
/// tarjetas tipo radio. Devuelve la elección o null si se cierra.
Future<ProductChoiceResult?> showProductChoiceSheet(
  BuildContext context, {
  required IngredientAvailability item,
  required List<IngredientProductOption> options,
  required int? selectedId,
  String? quantity,
  bool preferLowerPrice = false,
  Map<int, int> frequentProducts = const {},
}) {
  return showModalBottomSheet<ProductChoiceResult>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    sheetAnimationStyle: AnimationStyle(
      curve: Curves.easeOutCubic,
      duration: AppTheme.motion(context, AppTheme.slow),
    ),
    builder: (context) => _ProductChoiceSheet(
      item: item,
      options: options,
      selectedId: selectedId,
      quantity: quantity,
      preferLowerPrice: preferLowerPrice,
      frequentProducts: frequentProducts,
    ),
  );
}

class _ProductChoiceSheet extends StatefulWidget {
  const _ProductChoiceSheet({
    required this.item,
    required this.options,
    required this.selectedId,
    required this.quantity,
    required this.preferLowerPrice,
    required this.frequentProducts,
  });

  final IngredientAvailability item;
  final List<IngredientProductOption> options;
  final int? selectedId;
  final String? quantity;
  final bool preferLowerPrice;
  final Map<int, int> frequentProducts;

  @override
  State<_ProductChoiceSheet> createState() => _ProductChoiceSheetState();
}

class _ProductChoiceSheetState extends State<_ProductChoiceSheet> {
  late int? _selected =
      widget.options.any((option) => option.productId == widget.selectedId)
      ? widget.selectedId
      : widget.options.firstOrNull?.productId;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cheapest = widget.options.isEmpty
        ? null
        : widget.options.reduce((a, b) => b.price < a.price ? b : a).productId;
    final selected = widget.options
        .where((option) => option.productId == _selected)
        .firstOrNull;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('Ingrediente'),
                        const SizedBox(height: 4),
                        Text(
                          widget.quantity == null
                              ? item.name
                              : '${item.name} · ${widget.quantity}',
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
                  SmSquareButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Cerrar',
                    filled: true,
                    size: 52,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (widget.preferLowerPrice && widget.options.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.tint,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.auto_awesome_outlined,
                          size: 20,
                          color: AppTheme.green,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: AppTheme.ink,
                              fontSize: 16,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(text: 'Sueles elegir '),
                              TextSpan(
                                text: 'la opción más barata',
                                style: TextStyle(
                                  color: AppTheme.green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ', así que la marcamos primero. Puedes cambiarlo en Perfil.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Flexible(
              child: widget.options.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text(
                        'No hay productos de este ingrediente en esta sucursal.',
                        style: TextStyle(color: AppTheme.muted, fontSize: 16),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: widget.options.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final option = widget.options[index];
                        return StaggeredEntrance(
                          index: index,
                          child: _OptionCard(
                            option: option,
                            selected: option.productId == _selected,
                            cheapest:
                                option.productId == cheapest &&
                                widget.options.length > 1,
                            times: widget.frequentProducts[option.productId],
                            onTap: () =>
                                setState(() => _selected = option.productId),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, SetIngredientExcluded(!item.excluded)),
              style: TextButton.styleFrom(
                foregroundColor: item.excluded
                    ? AppTheme.green
                    : AppTheme.danger,
                minimumSize: const Size.fromHeight(56),
              ),
              child: Text(
                item.excluded ? 'Volver a la compra' : 'Quitar de la compra',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SmPrimaryButton(
                label: 'Usar este producto',
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(context, UseProduct(selected)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.selected,
    required this.cheapest,
    required this.times,
    required this.onTap,
  });

  final IngredientProductOption option;
  final bool selected;
  final bool cheapest;
  final int? times;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusL);
    final place = placeLabel(
      section: option.sectionName,
      shelf: option.shelf,
      fallback: option.unit,
    );
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: AnimatedContainer(
        duration: AppTheme.motion(context, AppTheme.fast),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppTheme.green : AppTheme.border,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProductPhoto(size: 80),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.name,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          place,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (cheapest)
                              const _Tag(
                                label: 'La más barata',
                                background: AppTheme.lime,
                                foreground: AppTheme.ink,
                              ),
                            if (times != null)
                              _Tag(
                                label: 'Compraste $times veces',
                                background: AppTheme.track,
                                foreground: AppTheme.green,
                              ),
                            if (option.isSubstitute)
                              const _Tag(
                                label: 'Reemplazo',
                                background: AppTheme.warningTint,
                                foreground: AppTheme.warning,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatBs(option.price),
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Radio(selected: selected),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppTheme.motion(context, AppTheme.fast),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppTheme.green : Colors.white,
        border: Border.all(
          color: selected ? AppTheme.green : const Color(0xFFDDE1D8),
          width: 2.5,
        ),
      ),
      child: AnimatedSwitcher(
        duration: AppTheme.motion(context, AppTheme.fast),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: selected
            ? const Icon(
                Icons.check_rounded,
                key: ValueKey('on'),
                size: 20,
                color: Colors.white,
              )
            : const SizedBox.shrink(key: ValueKey('off')),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Lugar de la foto del producto: el catálogo todavía no tiene imágenes.
class ProductPhoto extends StatelessWidget {
  const ProductPhoto({
    super.key,
    this.size = 80,
    this.dashed = false,
    this.color = const Color(0xFFFBE9E3),
    this.iconColor = const Color(0xFFA2462A),
  });

  final double size;

  /// Borde punteado, como en la parada siguiente.
  final bool dashed;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Icon(
        Icons.shopping_basket_outlined,
        size: size * 0.38,
        color: iconColor,
      ),
    );
    if (!dashed) return ExcludeSemantics(child: box);
    return ExcludeSemantics(
      child: CustomPaint(
        foregroundPainter: _DashedBorder(
          color: iconColor.withValues(alpha: 0.45),
          radius: size * 0.22,
        ),
        child: box,
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(1),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
