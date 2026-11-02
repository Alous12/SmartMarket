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
    required this.name,
    this.quantity,
    this.unit,
    this.inCatalog = false,
  });

  final String name;
  final double? quantity;
  final String? unit;

  /// Si corresponde a un ingrediente del catálogo del supermercado.
  final bool inCatalog;

  factory AssistantIngredient.fromJson(Map<String, dynamic> json) {
    return AssistantIngredient(
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      inCatalog: json['ingredient_id'] != null,
    );
  }
}

/// Petición escrita por el usuario y guardada por el backend.
class AssistantRequest {
  const AssistantRequest({
    required this.id,
    required this.prompt,
    required this.status,
    this.recipeName,
    this.message,
    this.ingredients = const [],
  });

  final int id;
  final String prompt;
  final AssistantRequestStatus status;

  /// Receta identificada por la IA.
  final String? recipeName;

  /// Explicación para el usuario cuando la petición se rechaza o falla.
  final String? message;
  final List<AssistantIngredient> ingredients;

  /// La IA ya terminó de procesar la petición.
  bool get isFinished =>
      status == AssistantRequestStatus.completed ||
      status == AssistantRequestStatus.rejected ||
      status == AssistantRequestStatus.failed;

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
      ingredients: [
        for (final item in ingredients.cast<Map<String, dynamic>>())
          AssistantIngredient.fromJson(item),
      ],
    );
  }
}
