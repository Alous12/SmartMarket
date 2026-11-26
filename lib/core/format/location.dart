/// Textos de ubicación dentro del supermercado.
library;

/// Sección con mayúscula inicial: `PASTAS` -> `Pastas`.
String sectionLabel(String section) {
  final words = section.trim().toLowerCase().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return '';
  return [
    words.first[0].toUpperCase() + words.first.substring(1),
    ...words.skip(1),
  ].join(' ');
}

/// Estante legible: `E01_10` -> `Estante E01-10`.
String shelfLabel(String shelf) => 'Estante ${shelf.replaceAll('_', '-')}';

/// `Pastas · Estante E01-10`, solo con las partes que existan.
String placeLabel({String? section, String? shelf, String? fallback}) {
  final parts = [
    if (section != null && section.trim().isNotEmpty) sectionLabel(section),
    if (shelf != null && shelf.trim().isNotEmpty) shelfLabel(shelf),
  ];
  if (parts.isEmpty) return fallback ?? '';
  return parts.join(' · ');
}

/// Número de espacio a partir del código del modelo: `SLOT_E01_09_0003` -> 3.
int? slotNumber(String slotCode) {
  final match = RegExp(r'(\d+)$').firstMatch(slotCode);
  return match == null ? null : int.tryParse(match.group(1)!);
}
