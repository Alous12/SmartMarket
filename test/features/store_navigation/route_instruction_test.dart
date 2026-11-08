import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/store_model.dart';
import 'package:smartmarket/features/store_navigation/domain/services/pedestrian_tracker.dart';
import 'package:smartmarket/features/store_navigation/domain/services/route_guidance.dart';
import 'package:smartmarket/features/store_navigation/domain/services/store_route_planner.dart';
import 'package:smartmarket/features/store_navigation/presentation/providers/store_model_provider.dart';
import 'package:smartmarket/features/store_navigation/presentation/widgets/route_instruction.dart';

StoreRouteNode _node(
  String id,
  double x,
  double z, [
  List<String> n = const [],
]) => StoreRouteNode(id: id, x: x, y: 0, z: z, neighbors: n);

void main() {
  // Al este 10 m y luego al sur 6 m hasta el tomate (a la derecha del pasillo).
  final nodes = [
    _node('entrada', 0, 0, ['esquina']),
    _node('esquina', 10, 0, ['tomate']),
    _node('tomate', 10, 6),
  ];
  const tomate = StoreProduct(
    id: 'T',
    name: 'Tomate',
    routeNode: 'tomate',
    x: 9,
    z: 6,
  );
  final plan = const StoreRoutePlanner().plan(
    routeNodes: nodes,
    products: const [tomate],
    startNodeId: 'entrada',
    productIds: const ['T'],
  );
  final guidance = RouteGuidance(plan.path);

  RouteInstruction at(double walked, {int index = 0}) => routeInstruction(
    session: NavigationSession(
      plan: plan,
      nextProductIndex: index,
      pose: WalkerPose(x: 0, z: 0, rotation: 0, walked: walked),
    ),
    guidance: guidance,
    nameOf: (product) => product.name,
  );

  test('anuncia el giro con su distancia', () {
    final instruction = at(2);
    expect(instruction.title, 'En 8 m, gira a la derecha');
    expect(instruction.subtitle, 'Busca Tomate');
    expect(instruction.icon, Icons.turn_right);
  });

  test('después del giro dice cuánto falta para la parada', () {
    expect(at(11).title, 'Sigue recto 5 m');
  });

  test('al llegar dice a qué lado está el producto', () {
    // Caminando hacia el sur, x = 9 queda a la derecha.
    expect(at(15.5).title, 'Está a tu derecha');
  });

  test('con el último producto la ruta termina, sin mandar a la caja', () {
    final instruction = at(16, index: 1);
    expect(instruction.title, 'Ruta completada');
    expect(instruction.subtitle, 'Ya recogiste todos tus productos');
  });

  test('sin ruta invita a armarla', () {
    final instruction = routeInstruction(
      session: const NavigationSession(),
      guidance: null,
      nameOf: (product) => product.name,
    );
    expect(instruction.title, 'Arma tu ruta');
  });
}
