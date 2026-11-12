enum IngredientStatus { available, unavailable, notInCatalog }

class IngredientProductOption {
  const IngredientProductOption({
    required this.productId,
    required this.branchId,
    required this.branchName,
    required this.name,
    required this.price,
    required this.unit,
    required this.ingredientName,
    required this.isSubstitute,
    required this.selected,
  });

  final int productId;
  final int branchId;
  final String branchName;
  final String name;
  final double price;
  final String unit;
  final String ingredientName;
  final bool isSubstitute;
  final bool selected;

  factory IngredientProductOption.fromJson(Map<String, dynamic> json) =>
      IngredientProductOption(
        productId: json['product_id'] as int,
        branchId: json['branch_id'] as int,
        branchName: json['branch_name'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        unit: json['unit_of_measure'] as String,
        ingredientName: json['ingredient_name'] as String,
        isSubstitute: json['is_substitute'] as bool,
        selected: json['selected'] as bool,
      );
}

/// Producto de un ingrediente en una sucursal.
class BranchProduct {
  const BranchProduct({required this.branchName, required this.productName});

  final String branchName;
  final String productName;

  factory BranchProduct.fromJson(Map<String, dynamic> json) {
    final products = (json['products'] as List).cast<Map<String, dynamic>>();
    return BranchProduct(
      branchName: json['branch_name'] as String,
      productName: products.first['name'] as String,
    );
  }
}

/// Resultado de comparar un ingrediente con el inventario.
class IngredientAvailability {
  const IngredientAvailability({
    required this.itemId,
    required this.name,
    required this.status,
    this.inOtherBranch = false,
    this.substitutes = const [],
    this.productOptions = const [],
    this.invalidSelectedBranches = const [],
  });

  final int itemId;
  final String name;

  /// Estado en la sucursal de la petición.
  final IngredientStatus status;

  /// Alguna otra sucursal tiene el ingrediente.
  final bool inOtherBranch;

  /// Productos que lo reemplazan en las sucursales donde falta.
  final List<BranchProduct> substitutes;
  final List<IngredientProductOption> productOptions;
  final List<int> invalidSelectedBranches;

  /// No hay producto de este ingrediente en ningún supermercado.
  bool get isNowhere => status != IngredientStatus.available && !inOtherBranch;

  static IngredientStatus _status(String value) => switch (value) {
    'AVAILABLE' => IngredientStatus.available,
    'UNAVAILABLE' => IngredientStatus.unavailable,
    'NOT_IN_CATALOG' => IngredientStatus.notInCatalog,
    _ => throw FormatException('Disponibilidad desconocida: $value'),
  };

  factory IngredientAvailability.fromJson(Map<String, dynamic> json) {
    return IngredientAvailability(
      itemId: json['item_id'] as int,
      name: json['name'] as String,
      status: _status(json['availability'] as String),
      inOtherBranch: (json['other_branches'] as List).isNotEmpty,
      substitutes: [
        for (final branch
            in (json['substitutes'] as List).cast<Map<String, dynamic>>())
          BranchProduct.fromJson(branch),
      ],
      productOptions: [
        for (final option
            in (json['product_options'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          IngredientProductOption.fromJson(option),
      ],
      invalidSelectedBranches:
          (json['invalid_selected_branches'] as List? ?? const []).cast<int>(),
    );
  }
}

/// Parada del recorrido: el producto elegido para un ingrediente de la lista.
class ShoppingRouteStop {
  const ShoppingRouteStop({
    required this.itemId,
    required this.ingredientName,
    required this.productId,
    required this.productName,
    required this.isSubstitute,
  });

  final int itemId;
  final String ingredientName;
  final int productId;
  final String productName;

  /// El producto reemplaza a un ingrediente que no hay en la sucursal.
  final bool isSubstitute;

  factory ShoppingRouteStop.fromJson(Map<String, dynamic> json) {
    return ShoppingRouteStop(
      itemId: json['item_id'] as int,
      ingredientName: json['ingredient_name'] as String,
      productId: json['product_id'] as int,
      productName: json['product_name'] as String,
      isSubstitute: json['is_substitute'] as bool,
    );
  }
}

/// Recorrido de compra por un supermercado.
class ShoppingRoute {
  const ShoppingRoute({
    required this.branchId,
    required this.branchName,
    required this.modelUrl,
    required this.stops,
    this.missing = const [],
  });

  final int branchId;
  final String branchName;

  /// Modelo 3D de la sucursal, con el que se identifica su mapa.
  final String? modelUrl;
  final List<ShoppingRouteStop> stops;

  /// Ingredientes de la lista que no entran en el recorrido.
  final List<String> missing;

  /// Paradas con el producto pedido, sin contar los reemplazos.
  int get exactCount => stops.where((stop) => !stop.isSubstitute).length;

  factory ShoppingRoute.fromJson(Map<String, dynamic> json) {
    return ShoppingRoute(
      branchId: json['branch_id'] as int,
      branchName: json['branch_name'] as String,
      modelUrl: json['model_3d_url'] as String?,
      stops: [
        for (final stop in (json['stops'] as List).cast<Map<String, dynamic>>())
          ShoppingRouteStop.fromJson(stop),
      ],
      missing: (json['missing'] as List).cast<String>(),
    );
  }
}

/// Disponibilidad de la lista de una receta en los supermercados.
class RecipeAvailability {
  const RecipeAvailability({
    required this.branchId,
    required this.items,
    this.routes = const [],
  });

  final int branchId;
  final List<IngredientAvailability> items;

  /// Un recorrido por supermercado con algo de la lista, de mejor a peor.
  final List<ShoppingRoute> routes;

  factory RecipeAvailability.fromJson(Map<String, dynamic> json) {
    return RecipeAvailability(
      branchId: json['branch_id'] as int,
      items: [
        for (final item in (json['items'] as List).cast<Map<String, dynamic>>())
          IngredientAvailability.fromJson(item),
      ],
      routes: [
        for (final route
            in (json['routes'] as List).cast<Map<String, dynamic>>())
          ShoppingRoute.fromJson(route),
      ],
    );
  }

  /// Ingredientes que no hay en ningún supermercado: son los únicos que se
  /// detallan al usuario.
  List<IngredientAvailability> get nowhere =>
      items.where((item) => item.isNowhere).toList();

  /// Ingredientes que existen en al menos un supermercado.
  int get _obtainable => items.length - nowhere.length;

  /// Supermercados donde se consigue todo lo que existe de la lista.
  List<ShoppingRoute> get _fullRoutes =>
      routes.where((route) => route.exactCount == _obtainable).toList();

  /// Algún supermercado tiene todo lo que existe de la lista.
  bool get hasFullRoute => _fullRoutes.isNotEmpty;

  /// Supermercados entre los que puede elegir el usuario.
  List<ShoppingRoute> get options => hasFullRoute ? _fullRoutes : routes;

  /// Resumen de la lista. [currentBranchId] es el supermercado abierto en el mapa.
  String summaryFor(int? currentBranchId) {
    if (routes.isEmpty) return 'Ningún supermercado tiene estos ingredientes.';
    if (_obtainable == 0) return 'Puedes comprar estos reemplazos.';
    final products = nowhere.isEmpty
        ? 'todos los productos'
        : 'los demás productos';
    final full = _fullRoutes;
    if (full.isEmpty) {
      return 'Ningún supermercado tiene todo. Elige dónde comprar.';
    }
    if (full.length > 1) {
      return 'Existen $products en ambos supermercados. Elige dónde comprar.';
    }
    final route = full.single;
    final place = route.branchId == currentBranchId
        ? 'este supermercado'
        : route.branchName;
    return 'Existen $products en $place.';
  }

  /// Qué le falta a un supermercado cuando ninguno tiene todo.
  List<String> detailsFor(ShoppingRoute route) {
    if (hasFullRoute) return const [];
    final nowhereItems = nowhere;
    final nowhereNames = {for (final item in nowhereItems) item.name};
    final nowhereIds = {for (final item in nowhereItems) item.itemId};
    final gaps = route.missing.where((name) => !nowhereNames.contains(name));
    return [
      'Tiene ${route.exactCount} de $_obtainable productos',
      if (gaps.isNotEmpty) 'Falta: ${gaps.join(', ')}',
      for (final stop in route.stops)
        if (stop.isSubstitute && !nowhereIds.contains(stop.itemId))
          'Reemplazo: ${stop.ingredientName} por ${stop.productName}',
    ];
  }
}
