import 'dart:math' as math;
import 'dart:typed_data';

import '../../../assistant/domain/entities/recipe_availability.dart';
import '../entities/floor_plan.dart';
import '../entities/store_model.dart';

/// Ids de las cajas del modelo que corresponden a las paradas de [route]. Las
/// paradas sin caja en el mapa se omiten.
List<String> storeProductIdsFor(
  ShoppingRoute route,
  List<StoreProduct> products,
) {
  final byDbId = {for (final product in products) ?product.dbId: product.id};
  return [for (final stop in route.stops) ?byDbId[stop.productId]];
}

class StoreRoutePlan {
  const StoreRoutePlan({
    required this.nodeIds,
    required this.stopNodeIds,
    required this.products,
    required this.distance,
    required this.path,
    required this.productDistances,
    required this.walkable,
  });

  final List<String> nodeIds;
  final List<String> stopNodeIds;
  final List<StoreProduct> products;

  /// Metros del recorrido, hasta el último producto.
  final double distance;

  /// Nodos del recorrido en orden, con su posición en el mapa.
  final List<StoreRouteNode> path;

  /// Distancia desde el inicio hasta cada producto de [products].
  final List<double> productDistances;

  /// Nodos de todos los pasillos: por donde se puede caminar.
  final List<StoreRouteNode> walkable;
}

/// Calcula recorridos como un navegador de calles, adaptado a un supermercado.
///
/// * El costo de un tramo son sus metros más un castigo por cada giro, así que
///   entre dos caminos casi igual de largos gana el que tiene menos vueltas.
/// * Recuerda por dónde llegaste a cada parada: salir dando media vuelta cuesta
///   más que seguir de frente.
/// * El orden de las paradas es el óptimo para listas de receta (hasta 10
///   paradas) y uno muy bueno para listas más largas.
/// * La ruta termina en el último producto.
/// * Con un [FloorPlan] une con una recta los puntos que se ven sin muebles en
///   medio, para no dibujar zigzags en zonas abiertas.
class StoreRoutePlanner {
  const StoreRoutePlanner({this.turnPenalty = 2.0, this.uTurnPenalty = 6.0});

  /// Metros que "cuesta" un giro de 90 grados.
  final double turnPenalty;

  /// Metros que "cuesta" dar media vuelta.
  final double uTurnPenalty;

  /// Hasta cuántas paradas se optimiza también la dirección de llegada.
  static const _exactWithHeading = 10;

  /// Hasta cuántas paradas el orden es exacto.
  static const _exactOrder = 12;

  StoreRoutePlan plan({
    required List<StoreRouteNode> routeNodes,
    required List<StoreProduct> products,
    required String startNodeId,
    required List<String> productIds,
    FloorPlan? floorPlan,
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

    for (final node in routeNodes) {
      for (final neighborId in node.neighbors) {
        if (!nodes.containsKey(neighborId)) {
          throw StateError(
            'El nodo "${node.id}" referencia el nodo inexistente '
            '"$neighborId".',
          );
        }
      }
    }

    final graph = _Graph(routeNodes, turnPenalty, uTurnPenalty);
    final startIndex = graph.index[start.id]!;
    final stopIds = productsByNode.keys.toList();
    final stops = [for (final id in stopIds) graph.index[id]!];

    final fromStart = graph.search(graph.fresh(startIndex));
    for (final stop in stops) {
      if (graph.bestStateAt(fromStart, stop) == null) {
        throw StateError(
          'No hay un camino transitable desde "${start.id}" hasta '
          '"${graph.nodes[stop].id}".',
        );
      }
    }
    final states = stops.length <= _exactWithHeading
        ? _orderWithHeading(graph, startIndex, stops)
        : _orderThenHeading(graph, startIndex, stops);

    // states: el inicio y una llegada por parada, en orden. Se unen los tramos
    // en un solo recorrido por los pasillos.
    final walk = <int>[startIndex];
    for (var leg = 1; leg < states.length; leg++) {
      final route = graph.pathTo(graph.search(states[leg - 1]), states[leg]);
      walk.addAll(route.skip(1));
    }

    // Cada producto se recoge la primera vez que la ruta pasa por él: si el
    // camino hacia otra parada pasa por delante, no tiene sentido seguir de largo
    // y volver después. El recorrido no cambia; termina en el último producto.
    final visits = <int, int>{};
    for (var at = 0; at < walk.length; at++) {
      if (productsByNode.containsKey(graph.nodes[walk[at]].id)) {
        visits.putIfAbsent(walk[at], () => at);
      }
    }
    final orderedIndexes = [...stops]
      ..sort((a, b) => visits[a]!.compareTo(visits[b]!));
    final orderedStops = [
      for (final stop in orderedIndexes) graph.nodes[stop].id,
    ];

    final fullPath = <int>[startIndex];
    var distance = 0.0;
    final legEnds = <double>[];
    var from = 0;
    for (final stop in orderedIndexes) {
      final to = visits[stop]!;
      final leg = walk.sublist(from, to + 1);
      final drawn = floorPlan == null
          ? leg
          : _straighten(leg, graph, floorPlan);
      for (var i = 1; i < drawn.length; i++) {
        distance += graph.nodes[drawn[i - 1]].distanceTo(graph.nodes[drawn[i]]);
        fullPath.add(drawn[i]);
      }
      legEnds.add(distance);
      from = to;
    }

    return StoreRoutePlan(
      nodeIds: List.unmodifiable([for (final i in fullPath) graph.nodes[i].id]),
      stopNodeIds: List.unmodifiable(orderedStops),
      products: List.unmodifiable([
        for (final id in orderedStops) ...productsByNode[id]!,
      ]),
      distance: distance,
      path: List.unmodifiable([for (final i in fullPath) graph.nodes[i]]),
      productDistances: List.unmodifiable([
        for (var stop = 0; stop < orderedStops.length; stop++)
          for (final _ in productsByNode[orderedStops[stop]]!) legEnds[stop],
      ]),
      walkable: routeNodes,
    );
  }

  /// Orden óptimo eligiendo también por dónde se llega a cada parada.
  ///
  /// Devuelve los estados de llegada: el inicio y cada parada en orden.
  List<int> _orderWithHeading(_Graph graph, int start, List<int> stops) {
    final count = stops.length;
    // Llegadas posibles a cada parada, aplanadas en una sola lista.
    final arrivals = <int>[];
    final stopOf = <int>[];
    final firstOf = <int>[];
    for (var stop = 0; stop < count; stop++) {
      firstOf.add(arrivals.length);
      for (final state in graph.statesAt(stops[stop])) {
        arrivals.add(state);
        stopOf.add(stop);
      }
    }
    firstOf.add(arrivals.length);
    final width = arrivals.length;
    final masks = 1 << count;
    final costs = Float64List(masks * width)
      ..fillRange(0, masks * width, double.infinity);
    final previous = Int32List(masks * width)..fillRange(0, masks * width, -1);

    final fromStart = graph.search(graph.fresh(start));
    for (var a = 0; a < width; a++) {
      costs[(1 << stopOf[a]) * width + a] = fromStart.cost[arrivals[a]];
    }
    for (var mask = 1; mask < masks; mask++) {
      for (var a = 0; a < width; a++) {
        final cost = costs[mask * width + a];
        if (cost == double.infinity || mask & (1 << stopOf[a]) == 0) continue;
        final search = graph.search(arrivals[a]);
        for (var next = 0; next < count; next++) {
          final bit = 1 << next;
          if (mask & bit != 0) continue;
          final nextMask = mask | bit;
          for (var b = firstOf[next]; b < firstOf[next + 1]; b++) {
            final candidate = cost + search.cost[arrivals[b]];
            if (candidate < costs[nextMask * width + b]) {
              costs[nextMask * width + b] = candidate;
              previous[nextMask * width + b] = a;
            }
          }
        }
      }
    }

    final full = masks - 1;
    var bestEnd = -1;
    var best = double.infinity;
    for (var a = 0; a < width; a++) {
      final cost = costs[full * width + a];
      if (cost < best) {
        best = cost;
        bestEnd = a;
      }
    }

    final order = <int>[];
    var mask = full;
    for (var a = bestEnd; a >= 0;) {
      order.add(arrivals[a]);
      final prior = previous[mask * width + a];
      mask ^= 1 << stopOf[a];
      a = prior;
    }
    return [graph.fresh(start), ...order.reversed];
  }

  /// Listas largas: primero el orden de las paradas sin mirar la dirección, y
  /// luego cada tramo sale según por dónde se llegó.
  List<int> _orderThenHeading(_Graph graph, int start, List<int> stops) {
    final searches = <int, _Search>{};
    _Search from(int node) =>
        searches.putIfAbsent(node, () => graph.search(graph.fresh(node)));
    double cost(int origin, int to) {
      final search = from(origin);
      return search.cost[graph.bestStateAt(search, to)!];
    }

    final order = stops.length <= _exactOrder
        ? _optimalStopOrder(start, stops, cost)
        : _approximateStopOrder(start, stops, cost);

    final states = [graph.fresh(start)];
    for (final stop in order) {
      final search = graph.search(states.last);
      states.add(graph.bestStateAt(search, stop)!);
    }
    return states;
  }

  List<int> _optimalStopOrder(
    int start,
    List<int> stops,
    double Function(int, int) cost,
  ) {
    final costs = <int, Map<int, double>>{};
    final previous = <int, Map<int, int>>{};
    for (var end = 0; end < stops.length; end++) {
      costs.putIfAbsent(1 << end, () => {})[end] = cost(start, stops[end]);
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
          final candidate = entry.value + cost(stops[entry.key], stops[next]);
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
    final order = <int>[];
    var mask = fullMask;
    while (end >= 0) {
      order.add(stops[end]);
      final prior = previous[mask]![end]!;
      mask ^= 1 << end;
      end = prior;
    }
    return order.reversed.toList();
  }

  List<int> _approximateStopOrder(
    int start,
    List<int> stops,
    double Function(int, int) cost,
  ) {
    final remaining = stops.toSet();
    final order = <int>[];
    var current = start;
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
          final before = first == 0 ? start : order[first - 1];
          final after = last == order.length - 1 ? null : order[last + 1];
          final oldCost =
              cost(before, order[first]) +
              (after == null ? 0 : cost(order[last], after));
          final newCost =
              cost(before, order[last]) +
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

  /// Une con una recta los puntos del tramo que se ven sin muebles en medio.
  /// Los extremos del tramo (paradas y caja) siempre se conservan.
  List<int> _straighten(List<int> leg, _Graph graph, FloorPlan plan) {
    if (leg.length < 3) return leg;
    bool clear(int from, int to) {
      final a = graph.nodes[leg[from]], b = graph.nodes[leg[to]];
      return plan.isClear(a.x, a.z, b.x, b.z);
    }

    final result = [leg.first];
    var anchor = 0;
    while (anchor < leg.length - 1) {
      var reach = anchor + 1;
      while (reach + 1 < leg.length && clear(anchor, reach + 1)) {
        reach++;
      }
      result.add(leg[reach]);
      anchor = reach;
    }
    return result;
  }
}

/// Grafo de pasillos con estados "estar en un nodo habiendo llegado desde otro",
/// para poder cobrar los giros.
class _Graph {
  _Graph(this.nodes, this.turnPenalty, this.uTurnPenalty)
    : index = {for (var i = 0; i < nodes.length; i++) nodes[i].id: i} {
    final sets = [for (final _ in nodes) <int>{}];
    for (var i = 0; i < nodes.length; i++) {
      for (final id in nodes[i].neighbors) {
        final j = index[id]!;
        if (i == j) continue;
        sets[i].add(j);
        sets[j].add(i);
      }
    }
    adjacency = [for (final set in sets) set.toList()..sort()];
    var next = nodes.length;
    for (var i = 0; i < nodes.length; i++) {
      firstArrival.add(next);
      next += adjacency[i].length;
    }
    stateCount = next;
    for (var i = 0; i < nodes.length; i++) {
      for (var k = 0; k < adjacency[i].length; k++) {
        stateNode.add(i);
        statePrevious.add(adjacency[i][k]);
      }
    }
  }

  final List<StoreRouteNode> nodes;
  final Map<String, int> index;
  final double turnPenalty;
  final double uTurnPenalty;
  late final List<List<int>> adjacency;

  /// Estado de llegada al nodo i desde su vecino k: firstArrival[i] + k.
  final firstArrival = <int>[];
  final stateNode = <int>[];
  final statePrevious = <int>[];
  late final int stateCount;
  final _searches = <int, _Search>{};

  /// Estar en [node] sin dirección: solo vale para el inicio.
  int fresh(int node) => node;

  int nodeOf(int state) =>
      state < nodes.length ? state : stateNode[state - nodes.length];

  int? _previousOf(int state) =>
      state < nodes.length ? null : statePrevious[state - nodes.length];

  Iterable<int> statesAt(int node) sync* {
    yield fresh(node);
    for (var k = 0; k < adjacency[node].length; k++) {
      yield firstArrival[node] + k;
    }
  }

  /// La forma más barata de estar en [node] según [search], o null si no se llega.
  int? bestStateAt(_Search search, int node) {
    int? best;
    for (final state in statesAt(node)) {
      if (search.cost[state] == double.infinity) continue;
      if (best == null || search.cost[state] < search.cost[best]) best = state;
    }
    return best;
  }

  double _turnCost(int from, int via, int to) {
    final a = nodes[from], b = nodes[via], c = nodes[to];
    final x1 = b.x - a.x, z1 = b.z - a.z;
    final x2 = c.x - b.x, z2 = c.z - b.z;
    final n1 = math.sqrt(x1 * x1 + z1 * z1), n2 = math.sqrt(x2 * x2 + z2 * z2);
    if (n1 < 1e-6 || n2 < 1e-6) return 0;
    final cosine = ((x1 * x2 + z1 * z2) / (n1 * n2)).clamp(-1.0, 1.0);
    final degrees = math.acos(cosine) * 180 / math.pi;
    if (degrees <= 20) return 0;
    if (degrees >= 150) return uTurnPenalty;
    return turnPenalty * degrees / 90;
  }

  /// Dijkstra sobre los estados, desde [source].
  _Search search(int source) => _searches.putIfAbsent(source, () {
    final cost = Float64List(stateCount)
      ..fillRange(0, stateCount, double.infinity);
    final parent = Int32List(stateCount)..fillRange(0, stateCount, -1);
    cost[source] = 0;
    final heap = _Heap()..push(0, source);
    while (heap.isNotEmpty) {
      final (current, state) = heap.pop();
      if (current > cost[state]) continue;
      final node = nodeOf(state);
      final from = _previousOf(state);
      final neighbors = adjacency[node];
      for (var k = 0; k < neighbors.length; k++) {
        final next = neighbors[k];
        final arrival = firstArrival[next] + adjacency[next].indexOf(node);
        final step =
            nodes[node].distanceTo(nodes[next]) +
            (from == null ? 0 : _turnCost(from, node, next));
        final candidate = current + step;
        if (candidate < cost[arrival]) {
          cost[arrival] = candidate;
          parent[arrival] = state;
          heap.push(candidate, arrival);
        }
      }
    }
    return _Search(source, cost, parent);
  });

  /// Nodos desde el origen de [search] hasta [target].
  List<int> pathTo(_Search search, int target) {
    final states = <int>[target];
    while (states.last != search.source) {
      final parent = search.parent[states.last];
      if (parent < 0) {
        throw StateError(
          'No se pudo reconstruir la ruta a "${nodes[nodeOf(target)].id}".',
        );
      }
      states.add(parent);
    }
    return [for (final state in states.reversed) nodeOf(state)];
  }
}

class _Search {
  const _Search(this.source, this.cost, this.parent);

  final int source;
  final Float64List cost;
  final Int32List parent;
}

/// Montículo mínimo de (costo, estado).
class _Heap {
  final _costs = <double>[];
  final _states = <int>[];

  bool get isNotEmpty => _costs.isNotEmpty;

  void push(double cost, int state) {
    _costs.add(cost);
    _states.add(state);
    var child = _costs.length - 1;
    while (child > 0) {
      final parent = (child - 1) >> 1;
      if (_costs[parent] <= _costs[child]) break;
      _swap(parent, child);
      child = parent;
    }
  }

  (double, int) pop() {
    final top = (_costs.first, _states.first);
    final lastCost = _costs.removeLast();
    final lastState = _states.removeLast();
    if (_costs.isNotEmpty) {
      _costs[0] = lastCost;
      _states[0] = lastState;
      var parent = 0;
      while (true) {
        final left = parent * 2 + 1, right = left + 1;
        var smallest = parent;
        if (left < _costs.length && _costs[left] < _costs[smallest]) {
          smallest = left;
        }
        if (right < _costs.length && _costs[right] < _costs[smallest]) {
          smallest = right;
        }
        if (smallest == parent) break;
        _swap(parent, smallest);
        parent = smallest;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final cost = _costs[a];
    _costs[a] = _costs[b];
    _costs[b] = cost;
    final state = _states[a];
    _states[a] = _states[b];
    _states[b] = state;
  }
}
