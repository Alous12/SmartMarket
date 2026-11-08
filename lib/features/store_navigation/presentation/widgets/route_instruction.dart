import 'package:flutter/material.dart';

import '../../domain/entities/store_model.dart';
import '../../domain/services/route_guidance.dart';
import '../providers/store_model_provider.dart';
import 'map_widgets.dart';

/// Lo que muestra la tarjeta de indicaciones.
class RouteInstruction {
  const RouteInstruction({
    required this.title,
    required this.subtitle,
    this.icon = Icons.turn_right,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

/// Indicación para el momento actual de [session], al estilo de un navegador:
/// "En 12 m, gira a la derecha", "Sigue recto 8 m", "Está a tu izquierda".
RouteInstruction routeInstruction({
  required NavigationSession session,
  required RouteGuidance? guidance,
  required String Function(StoreProduct product) nameOf,
}) {
  final plan = session.plan;
  if (plan == null) {
    return const RouteInstruction(
      title: 'Arma tu ruta',
      subtitle: 'Elige los productos que buscas',
    );
  }
  final walked = session.pose?.walked ?? 0;
  final current = session.current;
  if (current != null) {
    final target = plan.productDistances[session.nextProductIndex];
    final next = guidance?.next(
      walked: walked,
      target: target,
      product: current,
    );
    final subtitle = 'Busca ${nameOf(current)}';
    if (next == null) {
      return RouteInstruction(
        title: 'Dirígete a ${locationOf(current)}',
        subtitle: subtitle,
      );
    }
    if (!next.arriving) return _turn(next, subtitle);
    if (next.distance >= 2) {
      return RouteInstruction(
        title: 'Sigue recto ${next.distance.round()} m',
        subtitle: subtitle,
        icon: Icons.straight,
      );
    }
    return RouteInstruction(
      title: switch (next.side) {
        ProductSide.left => 'Está a tu izquierda',
        ProductSide.right => 'Está a tu derecha',
        ProductSide.ahead => 'Está al frente',
        null => 'Llegaste a ${locationOf(current)}',
      },
      subtitle: subtitle,
      icon: Icons.place,
    );
  }
  // Se recogió el último producto: ahí termina la ruta.
  return const RouteInstruction(
    title: 'Ruta completada',
    subtitle: 'Ya recogiste todos tus productos',
    icon: Icons.check_circle_outline,
  );
}

RouteInstruction _turn(NextInstruction next, String subtitle) {
  final action = switch (next.kind) {
    TurnKind.straight => 'sigue recto',
    TurnKind.slightLeft => 'gira levemente a la izquierda',
    TurnKind.left => 'gira a la izquierda',
    TurnKind.sharpLeft => 'gira cerrado a la izquierda',
    TurnKind.slightRight => 'gira levemente a la derecha',
    TurnKind.right => 'gira a la derecha',
    TurnKind.sharpRight => 'gira cerrado a la derecha',
    TurnKind.uTurn => 'da media vuelta',
  };
  final meters = next.distance.round();
  return RouteInstruction(
    title: meters >= 2
        ? 'En $meters m, $action'
        : '${action[0].toUpperCase()}${action.substring(1)}',
    subtitle: subtitle,
    icon: switch (next.kind) {
      TurnKind.straight => Icons.straight,
      TurnKind.slightLeft => Icons.turn_slight_left,
      TurnKind.left => Icons.turn_left,
      TurnKind.sharpLeft => Icons.turn_sharp_left,
      TurnKind.slightRight => Icons.turn_slight_right,
      TurnKind.right => Icons.turn_right,
      TurnKind.sharpRight => Icons.turn_sharp_right,
      TurnKind.uTurn => Icons.u_turn_left,
    },
  );
}
