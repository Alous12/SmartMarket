import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmarket/app/providers/store_providers.dart';
import 'package:smartmarket/app/smartmarket_app.dart';
import 'package:smartmarket/features/store_navigation/data/repositories/preferences_product_names_repository.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/store_model.dart';
import 'package:smartmarket/features/store_navigation/domain/repositories/store_model_repository.dart';

class _PendingRepository implements StoreModelRepository {
  final result = Completer<StoreModel>();
  final requested = <Supermarket>[];

  @override
  Future<StoreModel> load(Supermarket store) {
    requested.add(store);
    return result.future;
  }
}

class _FailingRepository implements StoreModelRepository {
  int calls = 0;

  @override
  Future<StoreModel> load(Supermarket store) async {
    calls++;
    throw const FormatException('Modelo inválido');
  }
}

void main() {
  testWidgets('La app abre el supermercado, muestra la carga y los 2 botones', (
    tester,
  ) async {
    final repository = _PendingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeModelRepositoryProvider.overrideWithValue(repository),
          productNamesRepositoryProvider.overrideWithValue(
            MemoryProductNamesRepository(),
          ),
        ],
        child: const SmartMarketApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Supermercado Natural'), findsOneWidget);
    expect(find.text('Natural'), findsOneWidget);
    expect(find.text('Piloto'), findsOneWidget);
    expect(find.text('Cargando el supermercado…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(repository.requested, [Supermarket.natural]);

    await tester.tap(find.text('Piloto'));
    await tester.pump();
    expect(find.text('SmartMarket Piloto'), findsOneWidget);
    expect(repository.requested.last, Supermarket.piloto);
  });

  testWidgets('Un error permite volver a cargar el asset', (tester) async {
    final repository = _FailingRepository();
    await tester.pumpWidget(
      ProviderScope(
        retry: (count, error) => null,
        overrides: [
          storeModelRepositoryProvider.overrideWithValue(repository),
          productNamesRepositoryProvider.overrideWithValue(
            MemoryProductNamesRepository(),
          ),
        ],
        child: const SmartMarketApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo cargar el modelo del supermercado.'),
      findsOneWidget,
    );
    expect(repository.calls, 1);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
  });
}
