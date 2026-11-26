import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/store_model.dart';

/// Colores de categoría en orden fijo (validados para daltonismo). «Otros»
/// va en gris neutro.
const _categoryColors = [
  Color(0xFF257DE0),
  Color(0xFFF47230),
  Color(0xFF00B894),
  Color(0xFFF2A600),
];
const _otherColor = Color(0xFF8A8F86);

/// Total de una medida por categoría, de mayor a menor.
List<(String, double)> _byCategory(
  List<StoreProduct> products,
  double Function(StoreProduct) measure,
) {
  final totals = <String, double>{};
  for (final product in products) {
    final category = product.category.isEmpty
        ? 'Sin categoría'
        : product.category;
    totals[category] = (totals[category] ?? 0) + measure(product);
  }
  return totals.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));
}

/// Tarjeta blanca con título y subtítulo para una gráfica.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.icon,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// Icono en un cuadro lima junto al título.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.lime,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Icon(icon, color: AppTheme.ink, size: 22),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 19,
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
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Barras horizontales: unidades en stock por categoría (las 6 mayores).
/// Una sola serie, un solo tono; el valor va escrito al final de cada barra.
class StockByCategoryChart extends StatefulWidget {
  const StockByCategoryChart({super.key, required this.products});

  final List<StoreProduct> products;

  @override
  State<StockByCategoryChart> createState() => _StockByCategoryChartState();
}

class _StockByCategoryChartState extends State<StockByCategoryChart> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final rows = _byCategory(
      widget.products.where((p) => p.stock != null).toList(),
      (p) => p.stock!,
    );
    // Las 8 categorías con más unidades; sumar el resto en una barra
    // achicaría a las demás.
    final shown = rows.take(8).toList();
    final max = shown.fold<double>(1, (m, r) => math.max(m, r.$2));
    if (shown.isEmpty) {
      return const Text(
        'Sin datos de stock.',
        style: TextStyle(color: AppTheme.muted),
      );
    }
    return Semantics(
      label: [
        for (final (name, value) in shown)
          '$name: ${compactNumber(value)} unidades',
      ].join('. '),
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (final (index, (name, value)) in shown.indexed)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    setState(() => _selected = _selected == name ? null : name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontSize: 14,
                            fontWeight: _selected == name
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: value / max),
                                duration: AppTheme.motion(
                                  context,
                                  Duration(milliseconds: 300 + index * 40),
                                ),
                                curve: Curves.easeOutCubic,
                                builder: (context, t, child) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: math.max(
                                      4,
                                      constraints.maxWidth * t,
                                    ),
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color:
                                          _selected == null || _selected == name
                                          ? AppTheme.green
                                          : AppTheme.green.withValues(
                                              alpha: 0.35,
                                            ),
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                            right: Radius.circular(4),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 44,
                        child: Text(
                          compactNumber(value),
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Torta (anillo) del valor del inventario por categoría: las 4 mayores y
/// «Otros». La leyenda lleva nombre, porcentaje y monto, así el color nunca es
/// la única pista.
class ValueByCategoryChart extends StatefulWidget {
  const ValueByCategoryChart({super.key, required this.products});

  final List<StoreProduct> products;

  @override
  State<ValueByCategoryChart> createState() => _ValueByCategoryChartState();
}

class _ValueByCategoryChartState extends State<ValueByCategoryChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final rows = _byCategory(
      widget.products.where((p) => p.stock != null).toList(),
      (p) => (p.price ?? 0) * p.stock!,
    );
    final total = rows.fold<double>(0, (sum, r) => sum + r.$2);
    if (total <= 0) {
      return const Text(
        'Sin datos de valor.',
        style: TextStyle(color: AppTheme.muted),
      );
    }
    final slices = <(String, double, Color)>[
      for (final (index, row) in rows.take(4).indexed)
        (row.$1, row.$2, _categoryColors[index]),
      if (rows.length > 4)
        (
          'Otros',
          rows.skip(4).fold<double>(0, (sum, r) => sum + r.$2),
          _otherColor,
        ),
    ];
    final selected = _selected == null ? null : slices[_selected!];
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: AppTheme.motion(
                  context,
                  const Duration(milliseconds: 400),
                ),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => CustomPaint(
                  size: const Size(190, 190),
                  painter: _DonutPainter(
                    slices: [for (final s in slices) (s.$2, s.$3)],
                    total: total,
                    progress: t,
                    selected: _selected,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selected == null ? 'Valor total' : selected.$1,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
                  Text(
                    formatBs(selected?.$2 ?? total),
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final (index, (name, value, color)) in slices.indexed)
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            onTap: () =>
                setState(() => _selected = _selected == index ? null : index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 15,
                        fontWeight: _selected == index
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${(value / total * 100).round()} %',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 14),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 92,
                    child: Text(
                      formatBs(value),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.progress,
    required this.selected,
  });

  final List<(double, Color)> slices;
  final double total;
  final double progress;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    const stroke = 30.0;
    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);
    // Separación de 2px entre porciones, en radianes sobre el radio medio.
    final gap = slices.length > 1 ? 2 / (radius - stroke / 2) : 0.0;
    var start = -math.pi / 2;
    final sweepTotal = 2 * math.pi * progress;
    for (final (index, (value, color)) in slices.indexed) {
      final sweep = sweepTotal * value / total;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected == index ? stroke + 6 : stroke
        ..color = selected == null || selected == index
            ? color
            : color.withValues(alpha: 0.35);
      if (sweep > gap) {
        canvas.drawArc(rect, start + gap / 2, sweep - gap, false, paint);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.slices != slices;
}
