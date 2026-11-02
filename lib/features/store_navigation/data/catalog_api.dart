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

  Future<void> _write(
    String method,
    String path, {
    Map<String, Object?>? body,
    required Set<int> okStatus,
    required String fallback,
  }) async {
    final token = await _tokenReader();
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll({
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(_timeout),
    );
    if (okStatus.contains(response.statusCode)) return;
    var message = fallback;
    try {
      final error = (jsonDecode(response.body) as Map)['error'];
      if (error is String) message = error;
    } on Object {
      // se usa el mensaje genérico
    }
    throw http.ClientException(message);
  }

  /// Quita el producto de la sucursal del admin (DELETE /products/:id).
  Future<void> removeProduct(int productId) => _write(
    'DELETE',
    '/products/$productId',
    okStatus: {204},
    fallback: 'No se pudo quitar el producto.',
  );

  /// Mueve el producto de un espacio a otro; si el destino está ocupado los intercambia.
  Future<void> moveSlot(String fromSlot, String toSlot) => _write(
    'POST',
    '/products/slots/move',
    body: {'from_slot': fromSlot, 'to_slot': toSlot},
    okStatus: {200},
    fallback: 'No se pudo mover el producto.',
  );

  Future<void> createInSlot(
    String slot, {
    required String name,
    required double price,
    required double stock,
    required int categoryId,
  }) => _write(
    'POST',
    '/products/slots/${Uri.encodeComponent(slot)}/product',
    body: {
      'name': name,
      'price': price,
      'stock_quantity': stock,
      'category_id': categoryId,
    },
    okStatus: {201},
    fallback: 'No se pudo agregar el producto.',
  );

  Future<void> updateProduct(
    int productId, {
    String? name,
    double? price,
    double? stock,
  }) => _write(
    'PATCH',
    '/products/$productId',
    body: {
      'name': ?name,
      'price': ?price,
      'stock_quantity': ?stock,
    },
    okStatus: {200},
    fallback: 'No se pudo guardar el producto.',
  );

  /// Categorías disponibles para productos nuevos (id -> nombre).
  Future<Map<int, String>> loadCategories() async {
    final options = await _get('/products/options') as Map<String, dynamic>;
    return {
      for (final c in (options['categories'] as List).cast<Map<String, dynamic>>())
        (c['category_id'] as num).toInt(): c['name'] as String,
    };
  }

  /// Id de la sucursal cuyo modelo 3D es [assetPath].
  Future<int> branchIdFor(String assetPath) async {
    final branches = await _get('/branches') as List;
    final branch = branches.cast<Map<String, dynamic>>().firstWhere(
      (b) => b['model_3d_url'] == assetPath,
    );
    return (branch['branch_id'] as num).toInt();
  }

  Future<CatalogSnapshot> loadSnapshot(String assetPath) async {
    final branchId = await branchIdFor(assetPath);
    final products = await _get('/branches/$branchId/products');
    final slots = await _get('/products/slots?branch_id=$branchId');
    final bySku = {
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
    return CatalogSnapshot(
      bySku: bySku,
      byId: {for (final p in bySku.values) p.productId: p},
      slots: {
        for (final s in (slots as List).cast<Map<String, dynamic>>())
          s['code'] as String: (s['product_id'] as num?)?.toInt(),
      },
    );
  }
}

/// Productos de una sucursal y qué producto ocupa cada espacio del modelo.
class CatalogSnapshot {
  const CatalogSnapshot({
    required this.bySku,
    required this.byId,
    required this.slots,
  });

  final Map<String, CatalogProduct> bySku;
  final Map<int, CatalogProduct> byId;

  /// Código de espacio (slot_id del modelo) -> producto que lo ocupa, o null si está libre.
  final Map<String, int?> slots;
}
