import 'dart:math' as math;
import 'dart:typed_data';

/// Plano del piso visto desde arriba: qué celdas se pueden caminar.
///
/// Una celda es libre si está cerca de un pasillo del grafo y lejos de los
/// muebles del modelo 3D. Sirve para saber si dos puntos de la ruta se ven sin
/// obstáculos y se pueden unir con una recta, como hace un mapa de calles al
/// simplificar un recorrido.
class FloorPlan {
  const FloorPlan({
    required this.minX,
    required this.minZ,
    required this.cellSize,
    required this.columns,
    required this.rows,
    required this.free,
  });

  final double minX;
  final double minZ;

  /// Lado de una celda en metros.
  final double cellSize;
  final int columns;
  final int rows;

  /// 1 si la celda se puede caminar, fila por fila.
  final Uint8List free;

  /// Distancia desde cada extremo que no se revisa: los nodos están en el
  /// pasillo aunque queden pegados a un estante.
  static const _endpointSlack = 0.35;

  bool isFree(double x, double z) {
    final column = ((x - minX) / cellSize).floor();
    final row = ((z - minZ) / cellSize).floor();
    if (column < 0 || row < 0 || column >= columns || row >= rows) return false;
    return free[row * columns + column] == 1;
  }

  /// Verdadero si la recta de (ax, az) a (bx, bz) va solo por celdas libres.
  bool isClear(double ax, double az, double bx, double bz) {
    final length = math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az));
    if (length <= 2 * _endpointSlack) return true;
    final steps = math.max(1, (length / (cellSize / 2)).ceil());
    for (var step = 0; step <= steps; step++) {
      final along = length * step / steps;
      if (along < _endpointSlack || along > length - _endpointSlack) continue;
      final t = along / length;
      if (!isFree(ax + (bx - ax) * t, az + (bz - az) * t)) return false;
    }
    return true;
  }
}
