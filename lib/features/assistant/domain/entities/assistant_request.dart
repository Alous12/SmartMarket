enum AssistantRequestStatus {
  received,
  processing,
  completed,
  rejected,
  failed,
}

/// Ingrediente de la lista generada por el asistente.
class AssistantIngredient {
  const AssistantIngredient({
    this.id,
    required this.name,
    this.quantity,
    this.unit,
    this.inCatalog = false,
  });

  /// Elemento de la lista guardada en el backend.
  final int? id;
  final String name;
  final double? quantity;
  final String? unit;

  /// Si corresponde a un ingrediente del catálogo del supermercado.
  final bool inCatalog;

  factory AssistantIngredient.fromJson(Map<String, dynamic> json) {
    return AssistantIngredient(
      id: json['item_id'] as int?,
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      inCatalog: json['ingredient_id'] != null,
    );
  }
}

/// Receta ya resuelta que se puede repetir sin volver a consultar a la IA.
class RecipeHistoryEntry {
  const RecipeHistoryEntry({
    required this.id,
    required this.recipeName,
    required this.ingredientCount,
    required this.createdAt,
  });

  /// Petición que generó la receta.
  final int id;
  final String recipeName;
  final int ingredientCount;
  final DateTime createdAt;

  factory RecipeHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RecipeHistoryEntry(
      id: json['request_id'] as int,
      recipeName: json['recipe_name'] as String,
      ingredientCount: json['ingredient_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

/// Petición escrita por el usuario y guardada por el backend.
/// Estado de stock de un producto en la respuesta del admin.
enum StockLevel { out, low, ok }

/// Producto con su stock que acompaña la respuesta del asistente del admin.
class AdminAnswerRow {
  const AdminAnswerRow({
    required this.productId,
    required this.name,
    required this.stock,
    required this.level,
  });

  final int productId;
  final String name;
  final double stock;
  final StockLevel level;

  factory AdminAnswerRow.fromJson(Map<String, dynamic> json) => AdminAnswerRow(
    productId: (json['product_id'] as num).toInt(),
    name: json['name'] as String,
    stock: (json['stock'] as num).toDouble(),
    level: switch (json['status']) {
      'out' => StockLevel.out,
      'low' => StockLevel.low,
      _ => StockLevel.ok,
    },
  );
}

class AssistantRequest {
  const AssistantRequest({
    required this.id,
    required this.prompt,
    required this.status,
    this.recipeName,
    this.message,
    this.ingredients = const [],
    this.rows = const [],
  });

  final int id;
  final String prompt;
  final AssistantRequestStatus status;

  /// Receta identificada por la IA.
  final String? recipeName;

  /// Explicación para el usuario cuando la petición se rechaza o falla.
  final String? message;
  final List<AssistantIngredient> ingredients;

  /// Barras de stock de una respuesta del admin; vacío si la respuesta no las trae.
  final List<AdminAnswerRow> rows;

  /// La IA ya terminó de procesar la petición.
  bool get isFinished =>
      status == AssistantRequestStatus.completed ||
      status == AssistantRequestStatus.rejected ||
      status == AssistantRequestStatus.failed;

  bool get isGeneralAnswer =>
      status == AssistantRequestStatus.completed &&
      recipeName == null &&
      message != null;

  factory AssistantRequest.fromJson(Map<String, dynamic> json) {
    final ingredients = json['ingredients'] as List? ?? const [];
    return AssistantRequest(
      id: json['request_id'] as int,
      prompt: json['prompt'] as String,
      status: AssistantRequestStatus.values.byName(
        (json['status'] as String).toLowerCase(),
      ),
      recipeName: json['recipe_name'] as String?,
      message: json['response_message'] as String?,
      rows: [
        for (final row
            in (json['rows'] as List? ?? const []).cast<Map<String, dynamic>>())
          AdminAnswerRow.fromJson(row),
      ],
      ingredients: [
        for (final item in ingredients.cast<Map<String, dynamic>>())
          AssistantIngredient.fromJson(item),
      ],
    );
  }
}
