import '../entities/store_model.dart';

/// Un espacio de estantería del plano: la caja del modelo y el producto de la
/// base de datos que lo ocupa (null si está libre).
class LayoutSlot {
  const LayoutSlot({required this.box, required this.product});

  /// Caja del modelo: da el código del espacio, el estante y la posición.
  final StoreProduct box;

  /// Producto que ocupa el espacio, o null si está libre.
  final StoreProduct? product;

  String get code => box.slotId;
  bool get isFree => product == null;
}

/// Un estante (shelf_id del modelo) con sus espacios en orden.
class LayoutShelf {
  const LayoutShelf({required this.code, required this.slots});

  final String code;
  final List<LayoutSlot> slots;

  int get freeCount => slots.where((slot) => slot.isFree).length;
}

/// Un pasillo o zona del supermercado con los estantes que dan a él.
class LayoutAisle {
  const LayoutAisle({
    required this.key,
    required this.label,
    required this.number,
    required this.shelves,
  });

  /// Identificador estable: `pasillo-3`, `zona-bebidas`…
  final String key;

  /// «Pasillo 3», «Bebidas», «Cabeceras»…
  final String label;

  /// Número del pasillo, o null si es una zona con nombre.
  final int? number;
  final List<LayoutShelf> shelves;

  Iterable<LayoutSlot> get slots => shelves.expand((shelf) => shelf.slots);
  int get slotCount => slots.length;
  int get freeCount => slots.where((slot) => slot.isFree).length;

  /// Categorías más frecuentes de lo que hay en el pasillo (máximo [limit]).
  List<String> categories({int limit = 3}) {
    final counts = <String, int>{};
    for (final slot in slots) {
      final category = slot.product?.category ?? '';
      if (category.isEmpty) continue;
      counts[category] = (counts[category] ?? 0) + 1;
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return sorted.take(limit).toList();
  }
}

/// Supermercado visto como pasillos, estantes y espacios.
class StoreLayout {
  StoreLayout(this.aisles)
    : _bySlot = {
        for (final aisle in aisles)
          for (final shelf in aisle.shelves)
            for (final slot in shelf.slots) slot.code: (aisle, shelf, slot),
      };

  final List<LayoutAisle> aisles;
  final Map<String, (LayoutAisle, LayoutShelf, LayoutSlot)> _bySlot;

  int get slotCount => _bySlot.length;
  int get freeCount => _bySlot.values.where((entry) => entry.$3.isFree).length;

  /// Pasillo, estante y espacio del código de espacio [code].
  (LayoutAisle, LayoutShelf, LayoutSlot)? locate(String code) => _bySlot[code];

  /// Dónde está el producto [productId] (id de la caja del modelo).
  (LayoutAisle, LayoutShelf, LayoutSlot)? locateProduct(String productId) =>
      _bySlot.values
          .where((entry) => entry.$3.product?.id == productId)
          .firstOrNull;

  /// Dónde está el producto con id [dbId] en la base de datos.
  (LayoutAisle, LayoutShelf, LayoutSlot)? locateDbProduct(int dbId) => _bySlot
      .values
      .where((entry) => entry.$3.product?.dbId == dbId)
      .firstOrNull;

  /// «Pasillo 3 · Estante E01-14 · espacio 2» del espacio [code].
  String placeOf(String code) {
    final entry = _bySlot[code];
    if (entry == null) return '';
    final (aisle, shelf, slot) = entry;
    final number = slotIndexOf(shelf, slot);
    return [
      aisle.label,
      shelfName(shelf.code),
      'espacio $number',
    ].join(' · ');
  }
}

/// Posición (desde 1) del espacio dentro de su estante.
int slotIndexOf(LayoutShelf shelf, LayoutSlot slot) =>
    shelf.slots.indexOf(slot) + 1;

/// «Estante E01-09» para el código de estante `E01_09`.
String shelfName(String code) => 'Estante ${code.replaceAll('_', '-')}';

/// Arma el plano con los espacios ocupados ([products], cajas con su producto
/// de la base de datos) y los libres ([emptySlots]).
///
/// El pasillo de cada espacio sale del nodo de ruta al que da su caja
/// (`node_pasillo_02_02` → «Pasillo 2»). Una góndola tiene dos caras: cada una
/// aparece en el pasillo al que da, como la ve quien lo recorre. Los espacios de
/// un estante que dan a una zona con nombre (Carnicería, Lácteos…) se juntan con
/// el resto del estante para no partirlo (ver `zoneWins`).
StoreLayout buildStoreLayout({
  required List<StoreProduct> products,
  required List<StoreProduct> emptySlots,
}) {
  final slots = [
    for (final product in products)
      if (product.slotId.isNotEmpty)
        LayoutSlot(box: product, product: product),
    for (final box in emptySlots)
      if (box.slotId.isNotEmpty) LayoutSlot(box: box, product: null),
  ];
  final shelves = <String, List<LayoutSlot>>{};
  for (final slot in slots) {
    final shelf = slot.box.shelfId ?? slot.box.shelf ?? _shelfFromSlot(slot);
    (shelves[shelf] ??= []).add(slot);
  }

  final aisles = <String, (String, int?, Map<String, List<LayoutSlot>>)>{};
  void place(String key, String label, int? number, String shelf, LayoutSlot slot) {
    final aisle = aisles[key] ??= (label, number, {});
    (aisle.$3[shelf] ??= []).add(slot);
  }

  for (final MapEntry(key: code, value: shelfSlots) in shelves.entries) {
    final found = [
      for (final slot in shelfSlots)
        (slot, aisleOf(routeNode: slot.box.routeNode, shelf: code)),
    ];
    (String, String, int?)? top(bool numbered) {
      final counts = <String, int>{};
      final info = <String, (String, String, int?)>{};
      for (final (_, aisle) in found) {
        if ((aisle.$3 != null) != numbered) continue;
        counts[aisle.$1] = (counts[aisle.$1] ?? 0) + 1;
        info[aisle.$1] = aisle;
      }
      if (counts.isEmpty) return null;
      final best = counts.keys.reduce((best, key) {
        final byCount = counts[key]!.compareTo(counts[best]!);
        if (byCount != 0) return byCount > 0 ? key : best;
        // Empate: el pasillo de menor número, o la zona por orden alfabético.
        final a = info[best]!, b = info[key]!;
        if (a.$3 != null && b.$3 != null) return b.$3! < a.$3! ? key : best;
        return b.$2.compareTo(a.$2) < 0 ? key : best;
      });
      return info[best];
    }

    final zone = top(false);
    final aisle = top(true);
    int count(String key) => found.where((entry) => entry.$2.$1 == key).length;
    final zoneSlots = found.where((entry) => entry.$2.$3 == null).length;
    // La zona se queda el estante si tiene más espacios que el pasillo
    // principal, o los mismos y además vende lo que dice su nombre (la
    // carnicería con carnes, no una góndola de champús junto a congelados).
    final zoneWins = switch ((zone, aisle)) {
      (final z?, final a?) =>
        zoneSlots > count(a.$1) ||
            (zoneSlots == count(a.$1) &&
                _sellsWhatItSays(z.$1, shelfSlots)),
      _ => false,
    };
    for (final (slot, own) in found) {
      final (key, label, number) = switch ((zone, aisle)) {
        // Solo pasillos numerados: cada cara va a su pasillo.
        (null, _) => own,
        // Solo zonas: el estante entero a la zona más numerosa.
        (final z?, null) => z,
        (final z?, final a?) => zoneWins ? z : (own.$3 != null ? own : a),
      };
      place(key, label, number, code, slot);
    }
  }

  final result = [
    for (final MapEntry(:key, value: (label, number, shelfMap))
        in aisles.entries)
      LayoutAisle(
        key: key,
        label: label,
        number: number,
        shelves: List.unmodifiable(
          [
            for (final MapEntry(key: code, value: list) in shelfMap.entries)
              LayoutShelf(
                code: code,
                slots: List.unmodifiable(list..sort(_bySlotNumber)),
              ),
          ]..sort((a, b) => _naturalCompare(a.code, b.code)),
        ),
      ),
  ]..sort(_byAisle);
  return StoreLayout(List.unmodifiable(result));
}

/// Pasillo de un espacio: clave, nombre y número (null si es una zona).
(String key, String label, int? number) aisleOf({
  required String routeNode,
  required String shelf,
}) {
  // Muebles que el modelo agrupa por su código: la pared del fondo y las
  // cabeceras de góndola dan a varios pasillos a la vez.
  if (RegExp(r'^FONDO', caseSensitive: false).hasMatch(shelf)) {
    return ('zona-fondo', 'Fondo', null);
  }
  if (RegExp(r'^CAB\d', caseSensitive: false).hasMatch(shelf)) {
    return ('zona-cabeceras', 'Cabeceras', null);
  }
  var node = routeNode.replaceFirst(RegExp(r'^node_'), '').toLowerCase();
  final aisle = RegExp(r'pasillo_?0*(\d+)').firstMatch(node);
  if (aisle != null) {
    final number = int.parse(aisle.group(1)!);
    return ('pasillo-$number', 'Pasillo $number', number);
  }
  if (node.contains('cabecera')) {
    return ('zona-cabeceras', 'Cabeceras', null);
  }
  if (node.contains('caja')) return ('zona-cajas', 'Cajas', null);
  node = node.replaceFirst(RegExp(r'^(caliente|frio|grid)_'), '');
  // Quita los sufijos de posición: _1, _a, _fondo, _frente, _fila…
  final suffix = RegExp(r'_(\d+|[a-z]|fondo|frente|fila)$');
  while (suffix.hasMatch(node)) {
    node = node.replaceFirst(suffix, '');
  }
  if (node.isEmpty) return ('zona-general', 'General', null);
  return ('zona-$node', _zoneLabel(node), null);
}

/// Nombres de zona con tildes y conectores: `frutas_verduras` → «Frutas y verduras».
const _zoneNames = {
  'frutas_verduras': 'Frutas y verduras',
  'higiene_limpieza': 'Higiene y limpieza',
  'lacteos': 'Lácteos',
  'carniceria': 'Carnicería',
  'panaderia': 'Panadería',
  'organicos': 'Orgánicos',
  'perimetro_este': 'Perímetro este',
  'perimetro_oeste': 'Perímetro oeste',
};

String _zoneLabel(String node) {
  final known = _zoneNames[node];
  if (known != null) return known;
  final text = node.replaceAll('_', ' ').trim();
  return text[0].toUpperCase() + text.substring(1);
}

/// Verdadero si alguna categoría de [slots] comparte una palabra con la zona
/// [zoneKey] (`zona-frutas_verduras` y «Frutas»).
bool _sellsWhatItSays(String zoneKey, List<LayoutSlot> slots) {
  Set<String> words(String text) => _plain(text)
      .split(RegExp(r'[^a-z]+'))
      .where((word) => word.length >= 4)
      .toSet();
  final zone = words(zoneKey.replaceFirst('zona-', ''));
  return slots.any(
    (slot) => words(
      slot.product?.category ?? slot.box.category,
    ).any(zone.contains),
  );
}

String _plain(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úù]'), 'u');

/// Estante de un espacio sin estante en el modelo: `SLOT_E01_09_0003` → `E01_09`.
String _shelfFromSlot(LayoutSlot slot) {
  final code = slot.code.replaceFirst(RegExp(r'^SLOT_'), '');
  final withoutNumber = code.replaceFirst(RegExp(r'_\d+$'), '');
  return withoutNumber.isEmpty ? code : withoutNumber;
}

int _bySlotNumber(LayoutSlot a, LayoutSlot b) => _naturalCompare(a.code, b.code);

/// Pasillos numerados primero y en orden; después las zonas por nombre.
int _byAisle(LayoutAisle a, LayoutAisle b) {
  if (a.number != null && b.number != null) {
    return a.number!.compareTo(b.number!);
  }
  if (a.number != null) return -1;
  if (b.number != null) return 1;
  return a.label.compareTo(b.label);
}

/// Compara textos con números como una persona: `G2` antes que `G10`.
int _naturalCompare(String a, String b) {
  final pattern = RegExp(r'(\d+)|(\D+)');
  final left = pattern.allMatches(a).map((m) => m.group(0)!).toList();
  final right = pattern.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < left.length && i < right.length; i++) {
    final x = int.tryParse(left[i]);
    final y = int.tryParse(right[i]);
    final compared = x != null && y != null
        ? x.compareTo(y)
        : left[i].compareTo(right[i]);
    if (compared != 0) return compared;
  }
  return left.length.compareTo(right.length);
}
