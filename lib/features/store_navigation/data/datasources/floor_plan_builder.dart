import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/entities/floor_plan.dart';
import '../../domain/entities/store_model.dart';

/// Arma el plano del piso con los triángulos del modelo (9 números por
/// triángulo, en coordenadas del mapa) y el grafo de pasillos.
///
/// Un triángulo es un obstáculo si ocupa la altura de una persona sobre el piso.
/// Una celda es libre si está a menos de [reach] de un pasillo del grafo y a más
/// de [clearance] de cualquier obstáculo.
FloorPlan? buildFloorPlan({
  required Float64List triangles,
  required List<StoreRouteNode> nodes,
  double cellSize = 0.2,
  double clearance = 0.3,
  double reach = 0.6,
}) {
  final obstacles = buildObstaclePlan(
    triangles: triangles,
    nodes: nodes,
    cellSize: cellSize,
    clearance: clearance,
    margin: reach + 1,
  );
  return obstacles == null
      ? null
      : walkablePlan(obstacles: obstacles, nodes: nodes, reach: reach);
}

/// Plano donde una celda es libre si está a más de [clearance] de cualquier
/// mueble, sin importar si hay un pasillo del grafo. Sirve para saber si dos
/// pasillos se comunican aunque el modelo no lo diga.
FloorPlan? buildObstaclePlan({
  required Float64List triangles,
  required List<StoreRouteNode> nodes,
  double cellSize = 0.2,
  double clearance = 0.3,
  double margin = 1.6,
}) {
  if (nodes.isEmpty || triangles.isEmpty) return null;
  var floor = double.infinity;
  var minX = double.infinity, maxX = double.negativeInfinity;
  var minZ = double.infinity, maxZ = double.negativeInfinity;
  for (final node in nodes) {
    floor = math.min(floor, node.y);
    minX = math.min(minX, node.x);
    maxX = math.max(maxX, node.x);
    minZ = math.min(minZ, node.z);
    maxZ = math.max(maxZ, node.z);
  }
  minX -= margin;
  minZ -= margin;
  final columns = ((maxX + margin - minX) / cellSize).ceil() + 1;
  final rows = ((maxZ + margin - minZ) / cellSize).ceil() + 1;
  if (columns * rows > 4000000) return null;

  final blocked = Uint8List(columns * rows);
  void mark(double x, double z) {
    final column = ((x - minX) / cellSize).floor();
    final row = ((z - minZ) / cellSize).floor();
    if (column < 0 || row < 0 || column >= columns || row >= rows) return;
    blocked[row * columns + column] = 1;
  }

  void markLine(double ax, double az, double bx, double bz) {
    final length = math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az));
    final steps = math.max(1, (length / (cellSize / 2)).ceil());
    for (var step = 0; step <= steps; step++) {
      final t = step / steps;
      mark(ax + (bx - ax) * t, az + (bz - az) * t);
    }
  }

  // Del piso hasta la altura de la cabeza: lo que bloquea el paso.
  final low = floor + 0.25, high = floor + 2.0;
  for (var offset = 0; offset + 9 <= triangles.length; offset += 9) {
    final ax = triangles[offset], ay = triangles[offset + 1];
    final az = triangles[offset + 2];
    final bx = triangles[offset + 3], by = triangles[offset + 4];
    final bz = triangles[offset + 5];
    final cx = triangles[offset + 6], cy = triangles[offset + 7];
    final cz = triangles[offset + 8];
    if (math.max(ay, math.max(by, cy)) < low) continue;
    if (math.min(ay, math.min(by, cy)) > high) continue;
    // Los bordes cubren las paredes, que vistas desde arriba son una línea.
    markLine(ax, az, bx, bz);
    markLine(bx, bz, cx, cz);
    markLine(cx, cz, ax, az);
    final area = (bx - ax) * (cz - az) - (cx - ax) * (bz - az);
    if (area.abs() < 1e-9) continue;
    final firstColumn = math.max(
      0,
      ((math.min(ax, math.min(bx, cx)) - minX) / cellSize).floor(),
    );
    final lastColumn = math.min(
      columns - 1,
      ((math.max(ax, math.max(bx, cx)) - minX) / cellSize).floor(),
    );
    final firstRow = math.max(
      0,
      ((math.min(az, math.min(bz, cz)) - minZ) / cellSize).floor(),
    );
    final lastRow = math.min(
      rows - 1,
      ((math.max(az, math.max(bz, cz)) - minZ) / cellSize).floor(),
    );
    for (var row = firstRow; row <= lastRow; row++) {
      final z = minZ + (row + 0.5) * cellSize;
      for (var column = firstColumn; column <= lastColumn; column++) {
        final x = minX + (column + 0.5) * cellSize;
        final u = ((bx - x) * (cz - z) - (cx - x) * (bz - z)) / area;
        final v = ((cx - x) * (az - z) - (ax - x) * (cz - z)) / area;
        if (u >= 0 && v >= 0 && u + v <= 1) blocked[row * columns + column] = 1;
      }
    }
  }

  // Margen alrededor de los muebles: nadie camina rozándolos.
  final radius = (clearance / cellSize).ceil();
  final limit = (clearance / cellSize) * (clearance / cellSize);
  final padded = Uint8List(columns * rows);
  for (var row = 0; row < rows; row++) {
    for (var column = 0; column < columns; column++) {
      if (blocked[row * columns + column] == 0) continue;
      for (var dz = -radius; dz <= radius; dz++) {
        for (var dx = -radius; dx <= radius; dx++) {
          if (dx * dx + dz * dz > limit + 1e-9) continue;
          final r = row + dz, c = column + dx;
          if (r < 0 || c < 0 || r >= rows || c >= columns) continue;
          padded[r * columns + c] = 1;
        }
      }
    }
  }

  final free = Uint8List(columns * rows);
  for (var index = 0; index < free.length; index++) {
    if (padded[index] == 0) free[index] = 1;
  }
  return FloorPlan(
    minX: minX,
    minZ: minZ,
    cellSize: cellSize,
    columns: columns,
    rows: rows,
    free: free,
  );
}

/// Deja libres solo las celdas de [obstacles] a menos de [reach] de un pasillo
/// del grafo: por ahí puede ir una recta de la ruta.
FloorPlan walkablePlan({
  required FloorPlan obstacles,
  required List<StoreRouteNode> nodes,
  double reach = 0.6,
}) {
  final minX = obstacles.minX, minZ = obstacles.minZ;
  final cellSize = obstacles.cellSize;
  final columns = obstacles.columns, rows = obstacles.rows;
  final near = Uint8List(columns * rows);
  void markNear(double ax, double az, double bx, double bz) {
    final firstColumn = math.max(
      0,
      ((math.min(ax, bx) - reach - minX) / cellSize).floor(),
    );
    final lastColumn = math.min(
      columns - 1,
      ((math.max(ax, bx) + reach - minX) / cellSize).floor(),
    );
    final firstRow = math.max(
      0,
      ((math.min(az, bz) - reach - minZ) / cellSize).floor(),
    );
    final lastRow = math.min(
      rows - 1,
      ((math.max(az, bz) + reach - minZ) / cellSize).floor(),
    );
    final dx = bx - ax, dz = bz - az;
    final squared = dx * dx + dz * dz;
    for (var row = firstRow; row <= lastRow; row++) {
      final z = minZ + (row + 0.5) * cellSize;
      for (var column = firstColumn; column <= lastColumn; column++) {
        final x = minX + (column + 0.5) * cellSize;
        final t = squared == 0
            ? 0.0
            : (((x - ax) * dx + (z - az) * dz) / squared).clamp(0.0, 1.0);
        final px = ax + dx * t - x, pz = az + dz * t - z;
        if (px * px + pz * pz <= reach * reach) {
          near[row * columns + column] = 1;
        }
      }
    }
  }

  final byId = {for (final node in nodes) node.id: node};
  for (final node in nodes) {
    markNear(node.x, node.z, node.x, node.z);
    for (final id in node.neighbors) {
      final other = byId[id];
      if (other == null || node.id.compareTo(id) >= 0) continue;
      markNear(node.x, node.z, other.x, other.z);
    }
  }

  final free = Uint8List(columns * rows);
  for (var index = 0; index < free.length; index++) {
    if (near[index] == 1 && obstacles.free[index] == 1) free[index] = 1;
  }
  return FloorPlan(
    minX: minX,
    minZ: minZ,
    cellSize: cellSize,
    columns: columns,
    rows: rows,
    free: free,
  );
}
