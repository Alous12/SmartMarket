import '../../domain/entities/store_model.dart';

/// Nombres para mostrar de cada supermercado. Solo presentación: el modelo
/// conserva `title` y `shortTitle`.
extension SupermarketLabels on Supermarket {
  String get displayName => switch (this) {
    Supermarket.natural => 'Supermercado Natural',
    Supermarket.piloto => 'SmartMarket Piloto',
  };
}
