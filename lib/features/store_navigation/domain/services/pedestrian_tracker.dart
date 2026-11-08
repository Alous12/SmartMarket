import 'dart:math' as math;

import '../entities/store_model.dart';

/// Dónde está y hacia dónde mira el muñeco.
class WalkerPose {
  const WalkerPose({
    required this.x,
    required this.z,
    required this.rotation,
    required this.walked,
  });

  final double x;
  final double z;

  /// Giro del muñeco en el mapa, con 0 mirando hacia +Z.
  final double rotation;

  /// Parte de la ruta ya recorrida.
  final double walked;

  Map<String, double> toJson() => {
    'x': x,
    'z': z,
    'rotation': rotation,
    'walked': walked,
  };
}

/// Sigue a la persona por el mapa con sus pasos y su orientación reales.
///
/// El mapa tiene un norte definido, y la brújula dice hacia dónde mira la persona
/// respecto de él. Sin brújula solo se conocen los giros: se asume que al empezar
/// mira hacia donde sale la ruta. La posición solo puede estar en los pasillos,
/// porque en la vida real nadie atraviesa un estante.
class PedestrianTracker {
  PedestrianTracker({
    required List<StoreRouteNode> route,
    required List<StoreRouteNode> walkable,
    this.stepLength = 0.7,
    double northDegrees = 0,
  }) : _northAngle = math.pi / 2 - northDegrees * math.pi / 180 {
    var start = 0.0;
    for (var index = 1; index < route.length; index++) {
      final from = route[index - 1];
      final to = route[index];
      final length = from.distanceTo(to);
      if (length < 1e-6) continue;
      final segment = _Segment(from.x, from.z, to.x, to.z, start, length);
      _route.add(segment);
      _corridors.add(segment);
      start += length;
    }
    final nodes = {for (final node in walkable) node.id: node};
    for (final node in walkable) {
      for (final id in node.neighbors) {
        final other = nodes[id];
        if (other == null || node.id.compareTo(id) >= 0) continue;
        _corridors.add(_Segment(node.x, node.z, other.x, other.z, 0, 0));
      }
    }
    if (route.isNotEmpty) {
      _x = route.first.x;
      _z = route.first.z;
    }
  }

  /// Media anchura de un pasillo. Debe ser menor que la mitad de lo que separa dos
  /// pasillos menos un paso, o el muñeco podría cruzar un estante (3,8 m en el mapa
  /// más estrecho).
  static const _corridor = 1.0;

  /// A qué distancia de la línea cuenta como estar pasando por ella.
  static const _routeReach = 2.0;

  /// Cuánto puede adelantarse la línea de una vez: evita saltarse tramos si la ruta
  /// vuelve a pasar cerca de sí misma.
  static const _lookAhead = 6.0;

  /// Largo de un paso en unidades del mapa (1 unidad equivale a 1 metro).
  final double stepLength;

  /// Dirección del norte en el mapa, antihoraria desde +X: arriba del mapa es -Z.
  final double _northAngle;

  final _route = <_Segment>[];
  final _corridors = <_Segment>[];
  double _x = 0;
  double _z = 0;
  double _walked = 0;
  double? _yaw;
  double? _offset;
  bool _aligned = false;

  double get walked => _walked;

  WalkerPose get pose {
    final angle = _heading;
    return WalkerPose(
      x: _x,
      z: _z,
      rotation: math.atan2(math.cos(angle), -math.sin(angle)),
      walked: _walked,
    );
  }

  /// Dirección en el mapa, en sentido antihorario visto desde arriba.
  double get _heading {
    final yaw = _yaw, offset = _offset;
    return yaw == null || offset == null ? _routeAngle : yaw + offset;
  }

  double get _routeAngle {
    if (_route.isEmpty) return 0;
    return _route
        .firstWhere(
          (segment) => _walked < segment.start + segment.length - 1e-6,
          orElse: () => _route.last,
        )
        .angle;
  }

  /// Nueva orientación del teléfono. Si es [absolute], 0 es el norte.
  void updateYaw(double? yaw, {bool absolute = false}) {
    _yaw = yaw;
    if (yaw == null) return;
    if (absolute && !_aligned) {
      _offset = _northAngle;
    } else {
      _offset ??= _routeAngle - yaw;
    }
  }

  /// Corrección manual: hacia donde mira la persona es hacia donde sigue la ruta.
  /// Tiene prioridad sobre la brújula hasta empezar otra ruta.
  void recenter() {
    final yaw = _yaw;
    if (yaw == null) return;
    _offset = _routeAngle - yaw;
    _aligned = true;
  }

  /// Ubica a la persona en un punto de la ruta: se usa al confirmar una parada.
  void moveTo(double distance) {
    _walked = distance;
    final (x, z) = _pointAt(distance);
    _x = x;
    _z = z;
  }

  /// Da un paso sobre la ruta, sin salirse de ella: la persona nunca atraviesa
  /// un estante y siempre sigue la línea. El teléfono solo decide hacia dónde
  /// mira. No avanza más allá de [limit], la próxima parada.
  void followStep({required double limit}) {
    moveTo(math.max(_walked, math.min(_walked + stepLength, limit)));
  }

  /// Da un paso. La línea no se consume más allá de [limit], la próxima parada.
  void step({required double limit}) {
    if (_yaw == null) {
      // Sin giroscopio ni brújula no hay dirección: solo se puede seguir la ruta.
      moveTo(math.min(_walked + stepLength, limit));
      return;
    }
    final angle = _heading;
    final (x, z) = _insideCorridor(
      _x + stepLength * math.cos(angle),
      _z - stepLength * math.sin(angle),
    );
    _x = x;
    _z = z;
    _consumeRoute(limit);
  }

  (double, double) _insideCorridor(double x, double z) {
    if (_corridors.isEmpty) return (x, z);
    var bestDistance = double.infinity;
    var nearestX = x, nearestZ = z;
    for (final corridor in _corridors) {
      final (px, pz) = corridor.nearestPoint(x, z);
      final distance = _distance(x, z, px, pz);
      if (distance < bestDistance) {
        bestDistance = distance;
        nearestX = px;
        nearestZ = pz;
      }
    }
    if (bestDistance <= _corridor) return (x, z);
    // Choca con el estante: se desliza por su borde en vez de detenerse.
    final scale = _corridor / bestDistance;
    return (
      nearestX + (x - nearestX) * scale,
      nearestZ + (z - nearestZ) * scale,
    );
  }

  void _consumeRoute(double limit) {
    final end = math.min(limit, _walked + _lookAhead);
    var bestDistance = double.infinity;
    var best = _walked;
    for (final segment in _route) {
      final segmentEnd = segment.start + segment.length;
      if (segmentEnd < _walked || segment.start > end) continue;
      final along = segment.start + segment.projection(_x, _z) * segment.length;
      final candidate = along.clamp(_walked, end);
      final (px, pz) = _pointAt(candidate);
      final distance = _distance(_x, _z, px, pz);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }
    if (bestDistance <= _routeReach) _walked = math.max(_walked, best);
  }

  (double, double) _pointAt(double distance) {
    if (_route.isEmpty) return (_x, _z);
    final segment = _route.firstWhere(
      (segment) => distance <= segment.start + segment.length,
      orElse: () => _route.last,
    );
    final t = ((distance - segment.start) / segment.length).clamp(0.0, 1.0);
    return (
      segment.ax + (segment.bx - segment.ax) * t,
      segment.az + (segment.bz - segment.az) * t,
    );
  }

  static double _distance(double ax, double az, double bx, double bz) {
    final dx = ax - bx, dz = az - bz;
    return math.sqrt(dx * dx + dz * dz);
  }
}

class _Segment {
  const _Segment(this.ax, this.az, this.bx, this.bz, this.start, this.length);

  final double ax;
  final double az;
  final double bx;
  final double bz;
  final double start;
  final double length;

  double get angle => math.atan2(-(bz - az), bx - ax);

  /// Fracción del tramo más cercana a un punto, entre 0 y 1.
  double projection(double x, double z) {
    final dx = bx - ax, dz = bz - az;
    final squared = dx * dx + dz * dz;
    if (squared == 0) return 0;
    return (((x - ax) * dx + (z - az) * dz) / squared).clamp(0.0, 1.0);
  }

  (double, double) nearestPoint(double x, double z) {
    final t = projection(x, z);
    return (ax + (bx - ax) * t, az + (bz - az) * t);
  }
}
