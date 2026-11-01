import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmarket/features/staff/data/staff_api.dart';

void main() {
  group('StaffApi', () {
    test(
      'carga opciones de categorías y secciones con autenticación',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url,
            Uri.parse('http://localhost:3000/api/products/options'),
          );
          expect(request.headers['authorization'], 'Bearer staff-token');
          return http.Response(
            jsonEncode({
              'data': {
                'categories': [
                  {'category_id': 3, 'name': 'Frutas'},
                ],
                'sections': [
                  {
                    'section_id': 8,
                    'name': 'Pasillo A',
                    'branch_id': 2,
                    'branch_name': 'Market Centro',
                  },
                ],
              },
            }),
            200,
          );
        });
        final api = StaffApi(
          client: client,
          baseUri: Uri.parse('http://localhost:3000/api'),
          tokenReader: () async => 'staff-token',
        );

        final options = await api.getOptions();

        expect(options.categories.single.name, 'Frutas');
        expect(options.sections.single.label, 'Market Centro · Pasillo A');
        client.close();
      },
    );

    test('envía la creación de producto con stock, ubicación y JWT', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url, Uri.parse('http://localhost:3000/api/products'));
        expect(request.headers['authorization'], 'Bearer staff-token');
        expect(jsonDecode(request.body), {
          'sku': 'FR-01',
          'name': 'Manzana',
          'price': 2.5,
          'unit_of_measure': 'kg',
          'category_id': 3,
          'stock_quantity': 12,
          'section_id': 8,
          'coordinate_x': 1.0,
          'coordinate_y': 2.0,
          'coordinate_z': 3.0,
        });
        return http.Response(jsonEncode({'data': []}), 201);
      });
      final api = StaffApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
        tokenReader: () async => 'staff-token',
      );

      await api.createProduct(
        const ProductDraft(
          sku: 'FR-01',
          name: 'Manzana',
          price: 2.5,
          unitOfMeasure: 'kg',
          categoryId: 3,
          stock: 12,
          location: LocationDraft(sectionId: 8, x: 1, y: 2, z: 3),
        ),
      );
      client.close();
    });

    test('cambia la ubicación del producto enviando el JWT', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(
          request.url,
          Uri.parse('http://localhost:3000/api/products/19/location'),
        );
        expect(request.headers['authorization'], 'Bearer staff-token');
        expect(jsonDecode(request.body), {
          'section_id': 9,
          'coordinate_x': 4.0,
          'coordinate_y': 5.0,
          'coordinate_z': 6.0,
        });
        return http.Response(jsonEncode({'data': []}), 200);
      });
      final api = StaffApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
        tokenReader: () async => 'staff-token',
      );

      await api.moveProduct(
        19,
        const LocationDraft(sectionId: 9, x: 4, y: 5, z: 6),
      );
      client.close();
    });

    test('expone los errores de autorización del backend', () async {
      final client = MockClient(
        (request) async =>
            http.Response(jsonEncode({'error': 'No tienes permisos.'}), 403),
      );
      final api = StaffApi(
        client: client,
        baseUri: Uri.parse('http://localhost:3000/api'),
        tokenReader: () async => 'customer-token',
      );

      await expectLater(
        api.getOptions(),
        throwsA(
          isA<StaffApiException>().having(
            (error) => error.message,
            'message',
            'No tienes permisos.',
          ),
        ),
      );
      client.close();
    });
  });
}
