import '../../../../core/format/location.dart';
import '../../domain/entities/assistant_request.dart';
import '../../domain/entities/recipe_availability.dart';

/// Ruta elegida y si el usuario quiere que se sigan sus pasos.
class RouteLaunch {
  const RouteLaunch(this.route, {this.tracking = true});

  final ShoppingRoute route;
  final bool tracking;
}

/// Cómo está un ingrediente en la sucursal elegida.
enum PlanStatus { available, substitute, missing, excluded }

/// Fila de la lista de compras: el ingrediente, qué se compra y dónde.
class PlanRow {
  const PlanRow({
    required this.item,
    required this.status,
    required this.detail,
    required this.options,
    this.selected,
  });

  final IngredientAvailability item;
  final PlanStatus status;
  final String detail;

  /// Opciones del ingrediente en la sucursal elegida.
  final List<IngredientProductOption> options;

  /// Producto que lleva la ruta (con su precio), si hay.
  final IngredientProductOption? selected;

  bool get needsAttention =>
      status == PlanStatus.substitute || status == PlanStatus.missing;
}

/// Cantidad legible del ingrediente: `500 g`, `2 unidades` o `al gusto`.
String ingredientQuantity(AssistantIngredient ingredient) {
  final quantity = ingredient.quantity;
  if (quantity == null) return 'al gusto';
  final amount = quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toString();
  return [amount, ?ingredient.unit].join(' ');
}

/// Cantidad pedida para [name] en la receta, si la IA la indicó.
String? quantityFor(List<AssistantIngredient> ingredients, String name) {
  final match = ingredients
      .where((i) => i.name.toLowerCase() == name.toLowerCase())
      .firstOrNull;
  if (match == null || match.quantity == null) return null;
  return ingredientQuantity(match);
}

/// Arma las filas de la lista para la sucursal de [route].
List<PlanRow> planRows(RecipeAvailability availability, ShoppingRoute? route) {
  final branchId = route?.branchId;
  return [
    for (final item in availability.items)
      _row(availability, item, route, branchId),
  ];
}

PlanRow _row(
  RecipeAvailability availability,
  IngredientAvailability item,
  ShoppingRoute? route,
  int? branchId,
) {
  final options = item.productOptions
      .where((option) => option.branchId == branchId)
      .toList();
  final stop = route?.stops.where((s) => s.itemId == item.itemId).firstOrNull;
  final selected = stop == null
      ? null
      : options.where((o) => o.productId == stop.productId).firstOrNull;
  if (item.excluded) {
    return PlanRow(
      item: item,
      status: PlanStatus.excluded,
      detail: 'Excluido de la compra',
      options: options,
    );
  }
  if (stop != null && !stop.isSubstitute) {
    return PlanRow(
      item: item,
      status: PlanStatus.available,
      detail: placeLabel(
        section: selected?.sectionName ?? stop.sectionName,
        shelf: selected?.shelf ?? stop.shelf,
        fallback: stop.productName,
      ),
      options: options,
      selected: selected,
    );
  }
  if (stop != null) {
    return PlanRow(
      item: item,
      status: PlanStatus.substitute,
      detail: 'Agotado · sustituto: ${stop.productName.toLowerCase()}',
      options: options,
      selected: selected,
    );
  }
  final elsewhere = availability.routes
      .where(
        (other) =>
            other.branchId != branchId &&
            other.stops.any((s) => s.itemId == item.itemId),
      )
      .firstOrNull;
  return PlanRow(
    item: item,
    status: PlanStatus.missing,
    detail: elsewhere != null
        ? 'Agotado · hay en ${elsewhere.branchName}'
        : options.isEmpty
        ? 'No hay en ningún supermercado'
        : 'Sin seleccionar: revisa las opciones',
    options: options,
  );
}
