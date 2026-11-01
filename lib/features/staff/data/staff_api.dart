import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class StaffApiException implements Exception {
  const StaffApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CategoryOption {
  const CategoryOption({required this.id, required this.name});

  final int id;
  final String name;
}

class SectionOption {
  const SectionOption({
    required this.id,
    required this.name,
    required this.branchId,
    required this.branchName,
  });

  final int id;
  final String name;
  final int branchId;
  final String branchName;

  String get label => '$branchName · $name';
}

class StaffOptions {
  const StaffOptions({required this.categories, required this.sections});

  final List<CategoryOption> categories;
  final List<SectionOption> sections;
}

class ProductLocation {
  const ProductLocation({
    required this.productId,
    required this.sku,
    required this.name,
    required this.branchName,
    required this.sectionId,
    required this.sectionName,
    required this.x,
    required this.y,
    required this.z,
    required this.shelf,
  });

  final int productId;
  final String sku;
  final String name;
  final String? branchName;
  final int? sectionId;
  final String? sectionName;
  final double? x;
  final double? y;
  final double? z;
  final String? shelf;
}

class LocationDraft {
  const LocationDraft({
    required this.sectionId,
    required this.x,
    required this.y,
    required this.z,
    this.shelf,
  });

  final int sectionId;
  final double x;
  final double y;
  final double z;
  final String? shelf;

  Map<String, Object?> toJson() => {
    'section_id': sectionId,
    'coordinate_x': x,
    'coordinate_y': y,
    'coordinate_z': z,
    if (shelf != null && shelf!.isNotEmpty) 'shelf': shelf,
  };
}

class ProductDraft {
  const ProductDraft({
    required this.sku,
    required this.name,
    required this.price,
    required this.unitOfMeasure,
    required this.categoryId,
    required this.stock,
    required this.location,
    this.brand,
  });

  final String sku;
  final String name;
  final double price;
  final String unitOfMeasure;
  final int categoryId;
  final double stock;
  final String? brand;
  final LocationDraft location;
}

class StaffApi {
  StaffApi({
    required this._client,
    required Uri baseUri,
    required this._tokenReader,
  }) : _productsUri = Uri.parse(
         '${baseUri.toString().replaceFirst(RegExp(r'/+$'), '')}/products',
       );

  final http.Client _client;
  final Future<String?> Function() _tokenReader;
  final Uri _productsUri;
  static const _timeout = Duration(seconds: 10);

  Future<StaffOptions> getOptions() async {
    final data = await _request('GET', Uri.parse('$_productsUri/options'));
    try {
      final map = data as Map<String, dynamic>;
      return StaffOptions(
        categories: [
          for (final c in map['categories'] as List)
            CategoryOption(
              id: (c as Map)['category_id'] as int,
              name: c['name'] as String,
            ),
        ],
        sections: [
          for (final s in map['sections'] as List)
            SectionOption(
              id: (s as Map)['section_id'] as int,
              name: s['name'] as String,
              branchId: s['branch_id'] as int,
              branchName: s['branch_name'] as String,
            ),
        ],
      );
    } on Object {
      throw const StaffApiException('El servidor devolvió datos inválidos.');
    }
  }

  Future<List<ProductLocation>> getProducts() async {
    final data = await _request('GET', _productsUri);
    try {
      return [
        for (final p in data as List)
          ProductLocation(
            productId: (p as Map)['product_id'] as int,
            sku: p['sku'] as String,
            name: p['name'] as String,
            branchName: p['branch_name'] as String?,
            sectionId: p['section_id'] as int?,
            sectionName: p['section_name'] as String?,
            x: double.tryParse('${p['coordinate_x']}'),
            y: double.tryParse('${p['coordinate_y']}'),
            z: double.tryParse('${p['coordinate_z']}'),
            shelf: p['shelf'] as String?,
          ),
      ];
    } on Object {
      throw const StaffApiException(
        'El servidor devolvió productos inválidos.',
      );
    }
  }

  Future<void> createProduct(ProductDraft draft) =>
      _request('POST', _productsUri, {
        'sku': draft.sku,
        'name': draft.name,
        'price': draft.price,
        'unit_of_measure': draft.unitOfMeasure,
        'category_id': draft.categoryId,
        'stock_quantity': draft.stock,
        if (draft.brand != null && draft.brand!.isNotEmpty)
          'brand': draft.brand,
        ...draft.location.toJson(),
      });

  Future<void> moveProduct(int productId, LocationDraft location) => _request(
    'PATCH',
    Uri.parse('$_productsUri/$productId/location'),
    location.toJson(),
  );

  Future<Object?> _request(String method, Uri uri, [Object? body]) async {
    final token = await _tokenReader();
    final request = http.Request(method, uri)
      ..headers['Authorization'] = 'Bearer ${token ?? ''}';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on SocketException {
      throw const StaffApiException('No se pudo conectar con el backend.');
    } on http.ClientException {
      throw const StaffApiException('No se pudo conectar con el backend.');
    } on TimeoutException {
      throw const StaffApiException('El backend tardó demasiado en responder.');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const StaffApiException(
        'El servidor devolvió una respuesta inválida.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map ? decoded['error'] : null;
      throw StaffApiException(
        error is String ? error : 'No se pudo completar la solicitud.',
      );
    }
    return decoded is Map ? decoded['data'] : null;
  }
}
