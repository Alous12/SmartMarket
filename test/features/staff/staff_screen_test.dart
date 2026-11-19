import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartmarket/features/staff/data/staff_api.dart';
import 'package:smartmarket/features/staff/presentation/providers/staff_providers.dart';
import 'package:smartmarket/features/staff/presentation/screens/staff_screen.dart';

void main() {
  testWidgets('el panel administrativo usa tarjetas y lista las ubicaciones', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/products/options')) {
        return http.Response(
          jsonEncode({
            'data': {
              'categories': [
                {'category_id': 1, 'name': 'Lácteos'},
              ],
              'sections': [
                {
                  'section_id': 2,
                  'name': 'Refrigerados',
                  'branch_id': 3,
                  'branch_name': 'Mercado Central',
                },
              ],
            },
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'data': [
            {
              'product_id': 9,
              'sku': 'LE-09',
              'name': 'Leche',
              'branch_name': 'Mercado Central',
              'section_id': 2,
              'section_name': 'Refrigerados',
              'coordinate_x': 1,
              'coordinate_y': 0,
              'coordinate_z': 4,
              'shelf': 'Estante B2',
            },
          ],
        }),
        200,
      );
    });
    final api = StaffApi(
      client: client,
      baseUri: Uri.parse('http://localhost:3000/api'),
      tokenReader: () async => 'token',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [staffApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: StaffScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Panel de administración'), findsOneWidget);
    expect(find.text('Inventario de la sucursal'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);

    await tester.tap(find.text('Cambiar de lugar'));
    await tester.pumpAndSettle();

    expect(find.text('Ubicaciones del mapa'), findsOneWidget);
    expect(find.text('Leche'), findsOneWidget);
    expect(find.textContaining('Estante B2'), findsOneWidget);
    client.close();
  });
}
