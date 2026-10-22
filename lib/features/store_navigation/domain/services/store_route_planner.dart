import '../entities/store_model.dart';

class StoreRoutePlan {
  const StoreRoutePlan({
    required this.nodeIds,
    required this.stopNodeIds,
    required this.products,
    required this.distance,
  });

  final List<String> nodeIds;
  final List<String> stopNodeIds;
  final List<StoreProduct> products;
  final double distance;
}

class StoreRoutePlanner {
  const StoreRoutePlanner();

  StoreRoutePlan plan({
    required List<StoreRouteNode> routeNodes,
    required List<StoreProduct> products,
    required String startNodeId,
    required List<String> productIds,
  }) {
    if (routeNodes.isEmpty) {
      throw StateError('El modelo no tiene nodos para calcular una ruta.');
    }
    final nodes = {for (final node in routeNodes) node.id: node};
    final start = nodes[startNodeId];
    if (start == null) {
      throw StateError('No existe el nodo de inicio "$startNodeId".');
    }
    if (productIds.isEmpty) {
      throw StateError('Agrega al menos un producto a la lista.');
    }

    final productsById = {for (final product in products) product.id: product};
    final productsByNode = <String, List<StoreProduct>>{};
    for (final id in productIds.toSet()) {
      final product = productsById[id];
      if (product == null) {
        throw StateError('No se encontró el producto "$id" en el modelo.');
      }
      final routeNode = nodes[product.routeNode];
      if (routeNode == null) {
        throw StateError(
          'El producto "${product.name}" no tiene un nodo de ruta válido.',
        );
      }
      productsByNode.putIfAbsent(routeNode.id, () => []).add(product);
    }

    final adjacency = <String, Set<String>>{
      for (final node in routeNodes) node.id: <String>{},
    };
    for (final node in routeNodes) {
      for (final neighborId in node.neighbors) {
        if (!nodes.containsKey(neighborId)) {
          throw StateError(
            'El nodo "${node.id}" referencia el nodo inexistente '
            '"$neighborId".',
          );
        }
        if (node.id == neighborId) continue;
        adjacency[node.id]!.add(neighborId);
        adjacency[neighborId]!.add(node.id);
      }
    }

    final stopIds = productsByNode.keys.toList();
    final shortestDistances = <String, Map<String, double>>{};
    Map<String, double> distancesFrom(String sourceId) =>
        shortestDistances.putIfAbsent(
          sourceId,
          () => _shortestDistancesFrom(sourceId, nodes, adjacency),
        );
    final orderedStops = _orderStops(
      startNodeId: start.id,
      stopIds: stopIds,
      distancesFrom: distancesFrom,
    );

    final fullPath = <String>[start.id];
    var distance = 0.0;
    var current = start.id;
    for (final destination in orderedStops) {
      final leg = _aStar(current, destination, nodes, adjacency);
      if (leg == null) {
        throw StateError(
          'No hay un camino transitable desde "$current" hasta '
          '"$destination".',
        );
      }
      fullPath.addAll(leg.nodeIds.skip(1));
      distance += leg.distance;
      current = destination;
    }

    return StoreRoutePlan(
      nodeIds: List.unmodifiable(fullPath),
      stopNodeIds: List.unmodifiable(orderedStops),
      products: List.unmodifiable([
        for (final id in orderedStops) ...productsByNode[id]!,
      ]),
      distance: distance,
    );
  }

  List<String> _orderStops({
    required String startNodeId,
    required List<String> stopIds,
    required Map<String, double> Function(String sourceId) distancesFrom,
  }) {
    if (stopIds.length <= 1) return stopIds;
    double cost(String from, String to) {
      final distance = distancesFrom(from)[to];
      if (distance == null) {
        throw StateError(
          'No hay un camino transitable desde "$from" hasta "$to".',
        );
      }
      return distance;
    }

    // Exact ordering is practical for recipe-sized lists; larger carts use 2-opt.
    if (stopIds.length <= 12) {
      return _optimalStopOrder(startNodeId, stopIds, cost);
    }
    return _approximateStopOrder(startNodeId, stopIds, cost);
  }

  List<String> _optimalStopOrder(
    String startId,
    List<String> stops,
    double Function(String, String) cost,
  ) {
    final costs = <int, Map<int, double>>{};
    final previous = <int, Map<int, int>>{};
    for (var end = 0; end < stops.length; end++) {
      costs.putIfAbsent(1 << end, () => {})[end] = cost(startId, stops[end]);
      previous.putIfAbsent(1 << end, () => {})[end] = -1;
    }

    for (var mask = 1; mask < (1 << stops.length); mask++) {
      final ends = costs[mask];
      if (ends == null) continue;
      for (final entry in ends.entries.toList()) {
        for (var next = 0; next < stops.length; next++) {
          final bit = 1 << next;
          if (mask & bit != 0) continue;
          final nextMask = mask | bit;
          final candidate =
              entry.value + cost(stops[entry.key], stops[next]);
          final best = costs.putIfAbsent(nextMask, () => {})[next];
          if (best == null || candidate < best) {
            costs[nextMask]![next] = candidate;
            previous.putIfAbsent(nextMask, () => {})[next] = entry.key;
          }
        }
      }
    }

    final fullMask = (1 << stops.length) - 1;
    final finalCosts = costs[fullMask]!;
    var end = finalCosts.keys.first;
    for (final candidate in finalCosts.keys.skip(1)) {
      if (finalCosts[candidate]! < finalCosts[end]!) end = candidate;
    }
    final order = <String>[];
    var mask = fullMask;
    while (end >= 0) {
      order.add(stops[end]);
      final prior = previous[mask]![end]!;
      mask ^= 1 << end;
      end = prior;
    }
    return order.reversed.toList();
  }

  List<String> _approximateStopOrder(
    String startId,
    List<String> stops,
    double Function(String, String) cost,
  ) {
    final remaining = stops.toSet();
    final order = <String>[];
    var current = startId;
    while (remaining.isNotEmpty) {
      final next = remaining.reduce(
        (a, b) => cost(current, a) <= cost(current, b) ? a : b,
      );
      order.add(next);
      remaining.remove(next);
      current = next;
    }

    var improved = true;
    while (improved) {
      improved = false;
      for (var first = 0; first < order.length - 1; first++) {
        for (var last = first + 1; last < order.length; last++) {
          final before = first == 0 ? startId : order[first - 1];
          final after = last == order.length - 1 ? null : order[last + 1];
          final oldCost = cost(before, order[first]) +
              (after == null ? 0 : cost(order[last], after));
          final newCost = cost(before, order[last]) +
              (after == null ? 0 : cost(order[first], after));
          if (newCost + 1e-9 < oldCost) {
            order.setRange(
              first,
              last + 1,
              order.sublist(first, last + 1).reversed,
            );
            improved = true;
          }
        }
      }
    }
    return order;
  }

  Map<String, double> _shortestDistancesFrom(
    String startId,
    Map<String, StoreRouteNode> nodes,
    Map<String, Set<String>> adjacency,
  ) {
    final distances = <String, double>{startId: 0};
    final open = <String>{startId};
    final closed = <String>{};
    while (open.isNotEmpty) {
      var current = open.first;
      for (final candidate in open) {
        if (distances[candidate]! < distances[current]!) current = candidate;
      }
      open.remove(current);
      closed.add(current);
      for (final neighborId in adjacency[current] ?? const <String>{}) {
        if (closed.contains(neighborId)) continue;
        final tentative =
            distances[current]! + nodes[current]!.distanceTo(nodes[neighborId]!);
        if (tentative >= (distances[neighborId] ?? double.infinity)) continue;
        distances[neighborId] = tentative;
        open.add(neighborId);
      }
    }
    return distances;
  }

  _Path? _aStar(
    String startId,
    String destinationId,
    Map<String, StoreRouteNode> nodes,
    Map<String, Set<String>> adjacency,
  ) {
    final distances = <String, double>{startId: 0};
    final cameFrom = <String, String>{};
    final open = <String>{startId};
    final closed = <String>{};

    while (open.isNotEmpty) {
      var current = open.first;
      var bestEstimate = double.infinity;
      for (final candidate in open) {
        final estimate = distances[candidate]! +
            nodes[candidate]!.distanceTo(nodes[destinationId]!);
        if (estimate < bestEstimate) {
          current = candidate;
          bestEstimate = estimate;
        }
      }
      if (current == destinationId) {
        final path = <String>[destinationId];
        while (path.last != startId) {
          final parent = cameFrom[path.last];
          if (parent == null) {
            throw StateError(
              'No se pudo reconstruir la ruta a "$destinationId".',
            );
          }
          path.add(parent);
        }
        return _Path(path.reversed.toList(), distances[destinationId]!);
      }
      open.remove(current);
      closed.add(current);

      for (final neighborId in adjacency[current] ?? const <String>{}) {
        if (closed.contains(neighborId)) continue;
        final tentative =
            distances[current]! + nodes[current]!.distanceTo(nodes[neighborId]!);
        if (tentative >= (distances[neighborId] ?? double.infinity)) continue;
        cameFrom[neighborId] = current;
        distances[neighborId] = tentative;
        open.add(neighborId);
      }
    }
    return null;
  }
}

class _Path {
  const _Path(this.nodeIds, this.distance);

  final List<String> nodeIds;
  final double distance;
}
