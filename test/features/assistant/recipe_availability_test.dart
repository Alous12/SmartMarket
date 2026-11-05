import 'package:flutter_test/flutter_test.dart';
import 'package:smartmarket/features/assistant/domain/entities/recipe_availability.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/store_model.dart';
import 'package:smartmarket/features/store_navigation/domain/services/store_route_planner.dart';

const _natural = 1;
const _piloto = 2;

IngredientAvailability _item(
  int id,
  String name, {
  bool here = true,
  bool elsewhere = false,
  List<BranchProduct> substitutes = const [],
}) => IngredientAvailability(
  itemId: id,
  name: name,
  status: here ? IngredientStatus.available : IngredientStatus.unavailable,
  inOtherBranch: elsewhere,
  substitutes: substitutes,
);

ShoppingRouteStop _stop(int itemId, {String? similar}) => ShoppingRouteStop(
  itemId: itemId,
  ingredientName: 'Ingrediente $itemId',
  productId: itemId * 10,
  productName: similar ?? 'Producto $itemId',
  isSubstitute: similar != null,
);

ShoppingRoute _route(
  int branchId,
  List<ShoppingRouteStop> stops, {
  List<String> missing = const [],
}) => ShoppingRoute(
  branchId: branchId,
  branchName: branchId == _natural ? 'Natural' : 'Piloto',
  modelUrl: 'modelo.glb',
  stops: stops,
  missing: missing,
);

void main() {
  group('Resumen de la lista', () {
    test('todo en el supermercado abierto', () {
      final availability = RecipeAvailability(
        branchId: _natural,
        items: [_item(1, 'Arroz'), _item(2, 'Sal')],
        routes: [
          _route(_natural, [_stop(1), _stop(2)]),
          _route(_piloto, [_stop(1)], missing: ['Sal']),
        ],
      );

      expect(
        availability.summaryFor(_natural),
        'Existen todos los productos en este supermercado.',
      );
      expect(availability.options.map((r) => r.branchId), [_natural]);
      expect(availability.detailsFor(availability.options.single), isEmpty);
    });

    test('todo en otro supermercado lo nombra', () {
      final availability = RecipeAvailability(
        branchId: _natural,
        items: [_item(1, 'Cebolla', here: false, elsewhere: true)],
        routes: [
          _route(_piloto, [_stop(1)]),
        ],
      );

      expect(
        availability.summaryFor(_natural),
        'Existen todos los productos en Piloto.',
      );
    });

    test('todo en los dos permite elegir', () {
      final availability = RecipeAvailability(
        branchId: _natural,
        items: [_item(1, 'Arroz', elsewhere: true)],
        routes: [
          _route(_natural, [_stop(1)]),
          _route(_piloto, [_stop(1)]),
        ],
      );

      expect(
        availability.summaryFor(_natural),
        'Existen todos los productos en ambos supermercados. '
        'Elige dónde comprar.',
      );
      expect(availability.options.length, 2);
    });

    test('un producto que no existe no impide elegir entre los dos', () {
      final availability = RecipeAvailability(
        branchId: _natural,
        items: [
          _item(1, 'Arroz', elsewhere: true),
          _item(2, 'Camarón', here: false),
        ],
        routes: [
          _route(_natural, [_stop(1)], missing: ['Camarón']),
          _route(_piloto, [_stop(1)], missing: ['Camarón']),
        ],
      );

      expect(availability.nowhere.map((item) => item.name), ['Camarón']);
      expect(
        availability.summaryFor(_natural),
        'Existen los demás productos en ambos supermercados. '
        'Elige dónde comprar.',
      );
      expect(availability.options.length, 2);
    });

    test('solo se detalla lo que no hay en ninguno', () {
      final availability = RecipeAvailability(
        branchId: _natural,
        items: [
          _item(1, 'Cebolla', here: false, elsewhere: true),
          _item(2, 'Sal', elsewhere: true),
          _item(3, 'Crema de leche', here: false),
        ],
      );

      expect(availability.nowhere.map((item) => item.name), ['Crema de leche']);
    });

    test('si ninguno tiene todo muestra qué le falta a cada uno', () {
      final natural = _route(
        _natural,
        [_stop(1), _stop(3, similar: 'Fideo')],
        missing: ['Cebolla', 'Camarón'],
      );
      final availability = RecipeAvailability(
        branchId: _natural,
        items: [
          _item(1, 'Sal', elsewhere: true),
          _item(2, 'Cebolla', here: false, elsewhere: true),
          _item(3, 'Masa', here: false, elsewhere: true),
          _item(4, 'Camarón', here: false),
        ],
        routes: [
          natural,
          _route(_piloto, [_stop(1), _stop(2)], missing: ['Masa', 'Camarón']),
        ],
      );

      expect(
        availability.summaryFor(_natural),
        'Ningún supermercado tiene todo. Elige dónde comprar.',
      );
      expect(availability.options.length, 2);
      expect(availability.detailsFor(natural), [
        'Tiene 1 de 3 productos',
        'Falta: Cebolla',
        'Reemplazo: Ingrediente 3 por Fideo',
      ]);
    });

    test('solo con reemplazos no dice que existen los productos', () {
      final availability = RecipeAvailability(
        branchId: _natural,
        items: [_item(1, 'Crema de leche', here: false)],
        routes: [
          _route(_natural, [_stop(1, similar: 'Leche')]),
        ],
      );

      expect(
        availability.summaryFor(_natural),
        'Puedes comprar estos reemplazos.',
      );
    });

    test('sin rutas no ofrece opciones', () {
      final availability = RecipeAvailability(
        branchId: _natural,
        items: [_item(1, 'Chorizo', here: false)],
      );

      expect(availability.options, isEmpty);
      expect(
        availability.summaryFor(_natural),
        'Ningún supermercado tiene estos ingredientes.',
      );
    });
  });

  group('Ruta del asistente en el mapa', () {
    const products = [
      StoreProduct(id: 'PIL_0005', name: 'Tomate', dbId: 10),
      StoreProduct(id: 'PIL_0006', name: 'Lechuga', dbId: 20),
      StoreProduct(id: 'SOLO_MODELO', name: 'Sin base de datos'),
    ];

    test('relaciona las paradas con las cajas del modelo', () {
      final route = _route(_piloto, [_stop(2), _stop(1)]);

      expect(storeProductIdsFor(route, products), ['PIL_0006', 'PIL_0005']);
    });

    test('omite las paradas que no tienen caja en el mapa', () {
      final route = _route(_piloto, [_stop(1), _stop(9)]);

      expect(storeProductIdsFor(route, products), ['PIL_0005']);
    });
  });
}
