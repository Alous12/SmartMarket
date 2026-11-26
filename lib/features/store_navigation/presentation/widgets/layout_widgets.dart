import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sm_buttons.dart';
import '../../domain/services/store_layout.dart';

/// Cómo se ve un espacio en el plano.
enum SlotTone { normal, focused, source, target }

/// Croquis de la tienda visto desde arriba: un cuadrito por espacio, verde el
/// pasillo elegido y su número en cada pasillo. Tocarlo elige el pasillo.
class StorePlan extends StatelessWidget {
  const StorePlan({
    super.key,
    required this.layout,
    required this.selectedAisle,
    required this.onAisleSelected,
    this.focusedSlot,
    this.sourceSlot,
  });

  final StoreLayout layout;
  final String? selectedAisle;
  final ValueChanged<String> onAisleSelected;
  final String? focusedSlot;
  final String? sourceSlot;

  @override
  Widget build(BuildContext context) {
    final geometry = _PlanGeometry.of(layout);
    if (geometry == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = (width / geometry.aspect).clamp(140.0, 240.0);
        final size = Size(width, height);
        final selected = layout.aisles
            .where((aisle) => aisle.key == selectedAisle)
            .firstOrNull;
        return Semantics(
          label:
              'Plano de la tienda. ${selected == null ? '' : 'Pasillo elegido: ${selected.label}. '}'
              'Toca un sector para elegir su pasillo.',
          child: GestureDetector(
            onTapUp: (details) {
              final hit = geometry.hitTest(details.localPosition, size);
              if (hit != null) onAisleSelected(hit);
            },
            child: CustomPaint(
              size: size,
              painter: _PlanPainter(
                geometry: geometry,
                selectedAisle: selectedAisle,
                focusedSlot: focusedSlot,
                sourceSlot: sourceSlot,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlanPoint {
  const _PlanPoint(this.x, this.z, this.aisle, this.code, this.free);

  final double x;
  final double z;
  final LayoutAisle aisle;
  final String code;
  final bool free;
}

/// Posiciones de los espacios y cómo llevarlas al tamaño del dibujo.
class _PlanGeometry {
  _PlanGeometry(this.points, this.minX, this.maxX, this.minZ, this.maxZ);

  static _PlanGeometry? of(StoreLayout layout) {
    final points = [
      for (final aisle in layout.aisles)
        for (final slot in aisle.slots)
          if (slot.box.x != null && slot.box.z != null)
            _PlanPoint(
              slot.box.x!,
              slot.box.z!,
              aisle,
              slot.code,
              slot.isFree,
            ),
    ];
    if (points.length < 2) return null;
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minZ = double.infinity, maxZ = double.negativeInfinity;
    for (final point in points) {
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minZ = math.min(minZ, point.z);
      maxZ = math.max(maxZ, point.z);
    }
    if (maxX - minX < 0.5 || maxZ - minZ < 0.5) return null;
    return _PlanGeometry(points, minX, maxX, minZ, maxZ);
  }

  final List<_PlanPoint> points;
  final double minX, maxX, minZ, maxZ;

  static const padding = 18.0;

  double get aspect => (maxX - minX) / (maxZ - minZ);

  /// Escala y origen para que el plano quepa centrado (x a la derecha, z abajo,
  /// como la vista superior del mapa 3D).
  (double scale, Offset origin) _fit(Size size) {
    final scale = math.min(
      (size.width - 2 * padding) / (maxX - minX),
      (size.height - 2 * padding) / (maxZ - minZ),
    );
    final origin = Offset(
      (size.width - (maxX - minX) * scale) / 2,
      (size.height - (maxZ - minZ) * scale) / 2,
    );
    return (scale, origin);
  }

  Offset toCanvas(_PlanPoint point, Size size) {
    final (scale, origin) = _fit(size);
    return origin + Offset((point.x - minX) * scale, (point.z - minZ) * scale);
  }

  /// Pasillo del espacio más cercano al toque (a menos de 28 px).
  String? hitTest(Offset position, Size size) {
    _PlanPoint? best;
    var bestDistance = 28.0;
    for (final point in points) {
      final distance = (toCanvas(point, size) - position).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = point;
      }
    }
    return best?.aisle.key;
  }
}

class _PlanPainter extends CustomPainter {
  _PlanPainter({
    required this.geometry,
    required this.selectedAisle,
    required this.focusedSlot,
    required this.sourceSlot,
  });

  final _PlanGeometry geometry;
  final String? selectedAisle;
  final String? focusedSlot;
  final String? sourceSlot;

  @override
  void paint(Canvas canvas, Size size) {
    final background = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppTheme.radiusL),
    );
    canvas.drawRRect(background, Paint()..color = AppTheme.background);

    const cell = 7.0;
    final points = [
      for (final point in geometry.points)
        (point, geometry.toCanvas(point, size)),
    ];

    // Franja suave detrás del pasillo elegido: lo resalta sin tapar nada.
    final chosen = [
      for (final (point, center) in points)
        if (point.aisle.key == selectedAisle) center,
    ];
    if (chosen.isNotEmpty) {
      var band = Rect.fromCenter(center: chosen.first, width: 0, height: 0);
      for (final center in chosen) {
        band = band.expandToInclude(
          Rect.fromCenter(center: center, width: 0, height: 0),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(band.inflate(9), const Radius.circular(8)),
        Paint()..color = AppTheme.lime.withAlpha(110),
      );
    }

    final idle = Paint()..color = const Color(0xFFCBD2C3);
    final selected = Paint()..color = AppTheme.green;
    final freeIdle = Paint()
      ..color = const Color(0xFFB4BBAD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final freeSelected = Paint()
      ..color = AppTheme.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final (point, center) in points) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: cell, height: cell),
        const Radius.circular(2),
      );
      final isSelected = point.aisle.key == selectedAisle;
      if (point.free) {
        canvas.drawRRect(rect, isSelected ? freeSelected : freeIdle);
      } else {
        canvas.drawRRect(rect, isSelected ? selected : idle);
      }
    }

    void ring(String? code, Color color) {
      if (code == null) return;
      final point = geometry.points.where((p) => p.code == code).firstOrNull;
      if (point == null) return;
      final center = geometry.toCanvas(point, size);
      canvas.drawCircle(center, 9, Paint()..color = color.withAlpha(90));
      canvas.drawCircle(
        center,
        9,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }

    ring(sourceSlot, AppTheme.warning);
    ring(focusedSlot, const Color(0xFF6BAF3F));

    // Solo el número de cada pasillo, en su centro. El elegido va en verde y se
    // dibuja primero para reservar su lugar; un número que chocaría con otro ya
    // dibujado se omite (su pasillo sigue en los chips de abajo).
    final centers = <LayoutAisle, (double, double, int)>{};
    for (final (point, c) in points) {
      if (point.aisle.number == null) continue;
      final (x, y, n) = centers[point.aisle] ?? (0.0, 0.0, 0);
      centers[point.aisle] = (x + c.dx, y + c.dy, n + 1);
    }
    final badges = centers.entries.toList()
      ..sort(
        (a, b) => (a.key.key == selectedAisle ? 0 : 1).compareTo(
          b.key.key == selectedAisle ? 0 : 1,
        ),
      );
    final placed = <Rect>[];
    final painted = <(Rect, String, bool)>[];
    for (final MapEntry(key: aisle, value: (x, y, n)) in badges) {
      final isSelected = aisle.key == selectedAisle;
      final rect = _badgeRect(
        size,
        Offset(x / n, y / n),
        '${aisle.number}',
        isSelected,
      );
      if (placed.any((other) => other.overlaps(rect.inflate(1)))) continue;
      placed.add(rect);
      painted.add((rect, '${aisle.number}', isSelected));
    }
    // El elegido se pinta al final para quedar encima.
    for (final (rect, text, isSelected) in painted.reversed) {
      _badge(canvas, rect, text, isSelected);
    }
  }

  static TextPainter _label(String text, bool selected) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: selected ? Colors.white : AppTheme.green,
        fontSize: selected ? 12 : 10.5,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  /// Círculo (o píldora, con dos cifras) del número, dentro del plano.
  Rect _badgeRect(Size size, Offset center, String text, bool selected) {
    final painter = _label(text, selected);
    final height = selected ? 24.0 : 19.0;
    final width = math.max(painter.width + 9, height);
    final left = (center.dx - width / 2).clamp(4.0, size.width - width - 4);
    final top = (center.dy - height / 2).clamp(4.0, size.height - height - 4);
    return Rect.fromLTWH(left, top, width, height);
  }

  void _badge(Canvas canvas, Rect rect, String text, bool selected) {
    final shape = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
    if (selected) {
      canvas.drawRRect(
        shape.shift(const Offset(0, 1)),
        Paint()
          ..color = Colors.black.withAlpha(40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas.drawRRect(
      shape,
      Paint()..color = selected ? AppTheme.green : Colors.white.withAlpha(235),
    );
    if (!selected) {
      canvas.drawRRect(
        shape,
        Paint()
          ..color = const Color(0xFFD5DBCF)
          ..style = PaintingStyle.stroke,
      );
    }
    final painter = _label(text, selected);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _PlanPainter old) =>
      !identical(old.geometry.points, geometry.points) ||
      old.selectedAisle != selectedAisle ||
      old.focusedSlot != focusedSlot ||
      old.sourceSlot != sourceSlot;
}

/// Fila de chips con todos los pasillos; el elegido se mantiene a la vista.
class AisleChips extends StatefulWidget {
  const AisleChips({
    super.key,
    required this.aisles,
    required this.selected,
    required this.onSelected,
  });

  final List<LayoutAisle> aisles;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  State<AisleChips> createState() => _AisleChipsState();
}

class _AisleChipsState extends State<AisleChips> {
  final _keys = <String, GlobalKey>{};

  @override
  void didUpdateWidget(covariant AisleChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _reveal();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keys[widget.selected]?.currentContext;
      if (context == null || !context.mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: AppTheme.motion(context, AppTheme.medium),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        itemCount: widget.aisles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final aisle = widget.aisles[index];
          return KeyedSubtree(
            key: _keys.putIfAbsent(aisle.key, GlobalKey.new),
            child: PillChip(
              label: aisle.label,
              selected: aisle.key == widget.selected,
              onTap: () => widget.onSelected(aisle.key),
            ),
          );
        },
      ),
    );
  }
}

/// Un estante con sus espacios en cuadrícula.
class ShelfCard extends StatelessWidget {
  const ShelfCard({
    super.key,
    required this.shelf,
    required this.toneOf,
    required this.nameOf,
    required this.onSlotTap,
  });

  final LayoutShelf shelf;
  final SlotTone Function(LayoutSlot slot) toneOf;
  final String Function(LayoutSlot slot) nameOf;
  final ValueChanged<LayoutSlot> onSlotTap;

  @override
  Widget build(BuildContext context) {
    final free = shelf.freeCount;
    final count = shelf.slots.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.tint,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: const Icon(
                  Icons.shelves,
                  size: 20,
                  color: AppTheme.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  shelfName(shelf.code),
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$count ${count == 1 ? 'espacio' : 'espacios'}'
                '${free == 0 ? '' : ' · $free ${free == 1 ? 'libre' : 'libres'}'}',
                style: const TextStyle(color: AppTheme.muted, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final columns = constraints.maxWidth > 520 ? 4 : 2;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final (index, slot) in shelf.slots.indexed)
                    SizedBox(
                      width: width,
                      child: SlotTile(
                        number: index + 1,
                        slot: slot,
                        name: nameOf(slot),
                        tone: toneOf(slot),
                        onTap: () => onSlotTap(slot),
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

/// Un espacio del estante: número, producto, precio y stock, o «Libre».
class SlotTile extends StatelessWidget {
  const SlotTile({
    super.key,
    required this.number,
    required this.slot,
    required this.name,
    required this.tone,
    required this.onTap,
  });

  final int number;
  final LayoutSlot slot;
  final String name;
  final SlotTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final product = slot.product;
    final stock = product?.stock;
    final (background, border) = switch (tone) {
      SlotTone.source => (AppTheme.warningTint, AppTheme.warning),
      SlotTone.focused => (const Color(0xFFE4F3D6), AppTheme.green),
      SlotTone.target => (Colors.white, AppTheme.green),
      SlotTone.normal => (
        product == null ? AppTheme.background : Colors.white,
        AppTheme.border,
      ),
    };
    final radius = BorderRadius.circular(AppTheme.radiusM);
    final description = product == null
        ? 'Espacio $number libre'
        : 'Espacio $number: $name'
              '${stock == null ? '' : ', ${_stockText(stock)}'}';
    return Semantics(
      button: true,
      label: description,
      hint: switch (tone) {
        SlotTone.source => 'Es el que estás moviendo. Toca para cancelar.',
        SlotTone.target => 'Toca para elegir este espacio.',
        _ => null,
      },
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppTheme.motion(context, AppTheme.fast),
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: Border.all(
            color: border,
            width: tone == SlotTone.normal ? 1.5 : 2.2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _NumberBadge(number: number, free: product == null),
                        const Spacer(),
                        if (product == null)
                          Icon(
                            tone == SlotTone.target
                                ? Icons.south_rounded
                                : Icons.add_rounded,
                            size: 20,
                            color: AppTheme.green,
                          )
                        else if (stock != null)
                          _StockDot(stock: stock),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product == null ? 'Libre' : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: product == null ? AppTheme.muted : AppTheme.ink,
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (product != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (product.price != null) formatBs(product.price!),
                          if (stock != null) '${compactNumber(stock)} u.',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _stockText(double stock) => stock <= 0
    ? 'agotado'
    : '${compactNumber(stock)} ${stock == 1 ? 'unidad' : 'unidades'}';

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, required this.free});

  final int number;
  final bool free;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: free ? Colors.white : AppTheme.tint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          color: AppTheme.green,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Punto de color del stock: rojo agotado, ámbar por agotarse, verde bien.
class _StockDot extends StatelessWidget {
  const _StockDot({required this.stock});

  final double stock;

  @override
  Widget build(BuildContext context) {
    final color = stock <= 0
        ? AppTheme.danger
        : stock <= 5
        ? const Color(0xFFD08A1C)
        : const Color(0xFF6BAF3F);
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Aviso fijo mientras se elige el espacio de destino.
class PlacementBanner extends StatelessWidget {
  const PlacementBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onCancel,
  });

  final String title;
  final String subtitle;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppTheme.warningTint,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(color: const Color(0xFFF1D7A8), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.swap_horiz_rounded, color: AppTheme.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.warning,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onCancel, child: const Text('Cancelar')),
          ],
        ),
      ),
    );
  }
}
