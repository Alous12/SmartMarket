import 'dart:math' as math;

import '../entities/store_model.dart';

/// Tipo de maniobra, como en un navegador de calles.
enum TurnKind {
  straight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,
}

/// Lado del pasillo donde está un producto, según hacia dónde se camina.
enum ProductSide { left, right, ahead }

/// Un giro de la ruta, a [at] metros del inicio.
class RouteTurn {
  const RouteTurn({required this.at, required this.kind});

  final double at;
  final TurnKind kind;
}

/// Lo próximo que debe hacer la persona.
class NextInstruction {
  const NextInstruction({
    required this.kind,
    required this.distance,
    required this.arriving,
    this.side,
  });

  /// Giro que viene; [TurnKind.straight] si lo próximo es llegar.
  final TurnKind kind;

  /// Metros hasta el giro o hasta la llegada.
  final double distance;

  /// Verdadero si antes de girar se llega al destino del tramo.
  final bool arriving;

  /// Lado del producto al llegar (null si no se conoce su posición).
  final ProductSide? side;
}

/// Indicaciones paso a paso de una ruta: dónde gira y hacia qué lado.
class RouteGuidance {
  RouteGuidance(List<StoreRouteNode> path)
    : _points = [for (final node in path) (node.x, node.z)] {
    var walked = 0.0;
    _starts.add(0);
    for (var i = 1; i < _points.length; i++) {
      walked += _length(_points[i - 1], _points[i]);
      _starts.add(walked);
    }
    turns = List.unmodifiable(_findTurns());
  }

  /// Giros más cercanos que esto se cuentan como uno solo.
  static const _mergeDistance = 1.5;

  final List<(double, double)> _points;

  /// Distancia desde el inicio hasta cada punto.
  final _starts = <double>[];
  late final List<RouteTurn> turns;

  double get length => _starts.isEmpty ? 0 : _starts.last;

  /// Qué viene después de [walked], antes de llegar a [target] metros. Con
  /// [product] se indica a qué lado queda al llegar.
  NextInstruction next({
    required double walked,
    required double target,
    StoreProduct? product,
  }) {
    for (final turn in turns) {
      // El giro donde se está parado (al salir de una parada) sigue vigente.
      if (turn.at < walked - 0.3) continue;
      if (turn.at >= target - 0.5) break;
      return NextInstruction(
        kind: turn.kind,
        distance: turn.at - walked,
        arriving: false,
      );
    }
    final px = product?.x, pz = product?.z;
    return NextInstruction(
      kind: TurnKind.straight,
      distance: math.max(0, target - walked),
      arriving: true,
      side: px == null || pz == null ? null : _sideAt(target, px, pz),
    );
  }

  List<RouteTurn> _findTurns() {
    // Ángulo con signo en cada vértice: positivo hacia la derecha.
    final raw = <(double, double)>[];
    for (var i = 1; i + 1 < _points.length; i++) {
      final angle = _signedAngle(_points[i - 1], _points[i], _points[i + 1]);
      if (angle == null || angle.abs() < 1) continue;
      raw.add((_starts[i], angle));
    }
    // Dos giros seguidos muy cerca (una diagonal que dobla una esquina) son uno.
    final merged = <(double, double)>[];
    for (final (at, angle) in raw) {
      if (merged.isNotEmpty && at - merged.last.$1 < _mergeDistance) {
        final (lastAt, lastAngle) = merged.removeLast();
        merged.add((lastAt, lastAngle + angle));
      } else {
        merged.add((at, angle));
      }
    }
    return [
      for (final (at, angle) in merged)
        if (_kindOf(angle) case final kind? when kind != TurnKind.straight)
          RouteTurn(at: at, kind: kind),
    ];
  }

  static TurnKind? _kindOf(double degrees) {
    final size = degrees.abs();
    if (size < 20) return TurnKind.straight;
    if (size >= 160) return TurnKind.uTurn;
    final right = degrees > 0;
    if (size < 60) return right ? TurnKind.slightRight : TurnKind.slightLeft;
    if (size < 135) return right ? TurnKind.right : TurnKind.left;
    return right ? TurnKind.sharpRight : TurnKind.sharpLeft;
  }

  /// Ángulo de giro en grados. En el mapa +X es el este y -Z el norte: un
  /// producto vectorial positivo es un giro a la derecha.
  static double? _signedAngle(
    (double, double) a,
    (double, double) b,
    (double, double) c,
  ) {
    final x1 = b.$1 - a.$1, z1 = b.$2 - a.$2;
    final x2 = c.$1 - b.$1, z2 = c.$2 - b.$2;
    if (math.sqrt(x1 * x1 + z1 * z1) < 1e-6) return null;
    if (math.sqrt(x2 * x2 + z2 * z2) < 1e-6) return null;
    final cross = x1 * z2 - z1 * x2;
    final dot = x1 * x2 + z1 * z2;
    return math.atan2(cross, dot) * 180 / math.pi;
  }

  ProductSide _sideAt(double distance, double px, double pz) {
    if (_points.length < 2) return ProductSide.ahead;
    // Tramo por el que se llega a ese punto de la ruta.
    var segment = 1;
    while (segment < _points.length - 1 && _starts[segment] < distance - 1e-6) {
      segment++;
    }
    var from = _points[segment - 1], to = _points[segment];
    // Un tramo de largo cero no tiene dirección: se usa el anterior.
    while (_length(from, to) < 1e-6 && segment > 1) {
      segment--;
      from = _points[segment - 1];
      to = _points[segment];
    }
    final length = _length(from, to);
    if (length < 1e-6) return ProductSide.ahead;
    final t = ((distance - _starts[segment - 1]) / length).clamp(0.0, 1.0);
    final x = from.$1 + (to.$1 - from.$1) * t;
    final z = from.$2 + (to.$2 - from.$2) * t;
    final dx = (to.$1 - from.$1) / length, dz = (to.$2 - from.$2) / length;
    final across = dx * (pz - z) - dz * (px - x);
    if (across.abs() < 0.3) return ProductSide.ahead;
    return across > 0 ? ProductSide.right : ProductSide.left;
  }

  static double _length((double, double) a, (double, double) b) {
    final dx = b.$1 - a.$1, dz = b.$2 - a.$2;
    return math.sqrt(dx * dx + dz * dz);
  }
}
