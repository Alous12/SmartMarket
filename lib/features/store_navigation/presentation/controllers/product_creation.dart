import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../app/providers/store_providers.dart';
import '../../domain/services/store_layout.dart';
import '../providers/store_model_provider.dart';
import '../widgets/new_product_form.dart';

/// Mensaje legible de un error de la API del catálogo.
String catalogErrorMessage(Object error, String fallback) =>
    error is http.ClientException && error.message.isNotEmpty
    ? error.message
    : fallback;

/// «Crear producto»: carga las categorías, abre el formulario y lo guarda en la
/// base de datos. Devuelve el nombre del producto creado, o null si se canceló
/// o falló (en ese caso ya avisó).
Future<String?> createProductFlow(
  BuildContext context,
  WidgetRef ref, {
  StoreLayout? layout,
  String? presetSlot,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final api = ref.read(catalogApiProvider);
  final Map<int, String> categories;
  try {
    categories = await api.loadCategories();
  } on Object catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          catalogErrorMessage(error, 'No se pudieron cargar las categorías.'),
        ),
      ),
    );
    return null;
  }
  if (!context.mounted) return null;
  final product = await showNewProductForm(
    context,
    categories: categories,
    layout: layout,
    presetSlot: presetSlot,
  );
  if (product == null) return null;
  try {
    await api.createProduct(product);
  } on Object catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          catalogErrorMessage(error, 'No se pudo crear el producto.'),
        ),
      ),
    );
    return null;
  }
  ref.invalidate(storeModelProvider);
  final where = product.slotCode == null
      ? 'quedó en el inventario'
      : 'quedó en ${layout?.placeOf(product.slotCode!) ?? 'su estante'}';
  messenger.showSnackBar(
    SnackBar(content: Text('"${product.name.trim()}" se creó y $where.')),
  );
  return product.name;
}
