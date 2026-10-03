import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/store_model.dart';
import '../../domain/repositories/store_model_repository.dart';

/// Guarda los nombres editados en el dispositivo (SharedPreferences, JSON).
class PreferencesProductNamesRepository implements ProductNamesRepository {
  PreferencesProductNamesRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  String _key(Supermarket store) => 'smartmarket.product_names.${store.name}';

  @override
  Future<Map<String, String>> load(Supermarket store) async {
    final raw = await _preferences.getString(_key(store));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((id, name) => MapEntry(id, name.toString()));
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> save(Supermarket store, Map<String, String> names) =>
      _preferences.setString(_key(store), jsonEncode(names));
}

/// Implementación en memoria para pruebas.
class MemoryProductNamesRepository implements ProductNamesRepository {
  final _names = <Supermarket, Map<String, String>>{};

  @override
  Future<Map<String, String>> load(Supermarket store) async =>
      Map.of(_names[store] ?? const {});

  @override
  Future<void> save(Supermarket store, Map<String, String> names) async {
    _names[store] = Map.of(names);
  }
}
