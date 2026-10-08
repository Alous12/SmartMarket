import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmarket/app/providers/store_providers.dart';
import 'package:smartmarket/app/smartmarket_app.dart';
import 'package:smartmarket/features/auth/data/auth_api.dart';
import 'package:smartmarket/features/auth/presentation/providers/auth_provider.dart';
import 'package:smartmarket/features/store_navigation/data/repositories/preferences_product_names_repository.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/store_model.dart';
import 'package:smartmarket/features/store_navigation/domain/repositories/store_model_repository.dart';

class _AuthenticatedAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async => const AuthSession(
    token: 'test-token',
    username: 'Ana',
    role: 'user',
  );
}

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
          authControllerProvider.overrideWith(
            _AuthenticatedAuthController.new,
          ),
          storeModelRepositoryProvider.overrideWithValue(repository),
          productNamesRepositoryProvider.overrideWithValue(
            MemoryProductNamesRepository(),
          ),
        ],
        child: const SmartMarketApp(),
      ),
    );
    await tester.pump();
    expect(find.text(Supermarket.natural.title), findsOneWidget);
    expect(find.text(Supermarket.natural.shortTitle), findsOneWidget);
    expect(find.text(Supermarket.piloto.shortTitle), findsOneWidget);
    expect(find.text('Cargando el supermercado…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(repository.requested, [Supermarket.natural]);

    await tester.tap(find.text(Supermarket.piloto.shortTitle));
    await tester.pump();
    expect(find.text(Supermarket.piloto.title), findsOneWidget);
    expect(repository.requested.last, Supermarket.piloto);
  });

  testWidgets('Volver desde el mapa requiere confirmar y permite continuar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            _AuthenticatedAuthController.new,
          ),
          storeModelRepositoryProvider.overrideWithValue(_PendingRepository()),
          productNamesRepositoryProvider.overrideWithValue(
            MemoryProductNamesRepository(),
          ),
        ],
        child: const SmartMarketApp(),
      ),
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('¿Salir de SmartMarket?'), findsOneWidget);
    await tester.tap(find.text('Seguir explorando'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('¿Salir de SmartMarket?'), findsNothing);
    expect(find.text(Supermarket.natural.title), findsOneWidget);
  });

  testWidgets('Un error permite volver a cargar el asset', (tester) async {
    final repository = _FailingRepository();
    await tester.pumpWidget(
      ProviderScope(
        retry: (count, error) => null,
        overrides: [
          authControllerProvider.overrideWith(
            _AuthenticatedAuthController.new,
          ),
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
