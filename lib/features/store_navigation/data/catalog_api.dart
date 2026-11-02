import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Datos de un producto guardados en la base de datos de la sucursal.
class CatalogProduct {
  const CatalogProduct({
    required this.productId,
    required this.sku,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
  });

  final int productId;
  final String sku;
  final String name;
  final String category;
  final double price;
  final double stock;
}

/// Lee de la API los productos de la sucursal cuyo modelo 3D es [assetPath].
class CatalogApi {
  CatalogApi({
    required http.Client client,
    required Uri baseUri,
    required Future<String?> Function() tokenReader,
  }) : _client = client,
       _baseUrl = baseUri.toString().replaceFirst(RegExp(r'/+$'), ''),
       _tokenReader = tokenReader;

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _tokenReader;
  static const _timeout = Duration(seconds: 5);

  Future<Object?> _get(String path) async {
    final token = await _tokenReader();
    final response = await _client
        .get(
          Uri.parse('$_baseUrl$path'),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}');
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['data'];
  }

  /// Quita el producto de la sucursal del admin (DELETE /products/:id).
  Future<void> removeProduct(int productId) async {
    final token = await _tokenReader();
    final response = await _client
        .delete(
          Uri.parse('$_baseUrl/products/$productId'),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);
    if (response.statusCode != 204) {
      var message = 'No se pudo quitar el producto.';
      try {
        final error = (jsonDecode(response.body) as Map)['error'];
        if (error is String) message = error;
      } on Object {
        // se usa el mensaje genérico
      }
      throw http.ClientException(message);
    }
  }

  Future<Map<String, CatalogProduct>> loadProducts(String assetPath) async {
    final branches = await _get('/branches') as List;
    final branch = branches.cast<Map<String, dynamic>>().firstWhere(
      (b) => b['model_3d_url'] == assetPath,
    );
    final products = await _get('/branches/${branch['branch_id']}/products');
    return {
      for (final p in (products as List).cast<Map<String, dynamic>>())
        p['sku'] as String: CatalogProduct(
          productId: (p['product_id'] as num).toInt(),
          sku: p['sku'] as String,
          name: p['name'] as String,
          category: p['category_name'] as String,
          price: (p['price'] as num).toDouble(),
          stock: (p['stock_quantity'] as num).toDouble(),
        ),
    };
  }
}
