import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmarket/app/providers/store_providers.dart';
import 'package:smartmarket/app/smartmarket_app.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/store_model.dart';
import 'package:smartmarket/features/store_navigation/domain/repositories/store_model_repository.dart';

class _PendingRepository implements StoreModelRepository {
  final result = Completer<StoreModel>();

  @override
  Future<StoreModel> load() => result.future;
}

class _FailingRepository implements StoreModelRepository {
  int calls = 0;

  @override
  Future<StoreModel> load() async {
    calls++;
    throw const FormatException('Modelo inválido');
  }
}

void main() {
  testWidgets('La app abre solo el supermercado y muestra la carga', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeModelRepositoryProvider.overrideWithValue(_PendingRepository()),
        ],
        child: const SmartMarketApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Mi supermercado'), findsOneWidget);
    expect(find.text('Cargando el supermercado…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Un error permite volver a cargar el asset', (tester) async {
    final repository = _FailingRepository();
    await tester.pumpWidget(
      ProviderScope(
        retry: (count, error) => null,
        overrides: [storeModelRepositoryProvider.overrideWithValue(repository)],
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
