/// Símbolo de la moneda de la app: bolivianos. Cambiarlo aquí lo cambia en
/// todas las pantallas.
const currencySymbol = 'Bs';

/// Precio en bolivianos con dos decimales y coma decimal: `Bs 12,50`.
/// Es solo presentación: el número que llega de la API no cambia.
String formatBs(num value) => '$currencySymbol ${formatAmount(value)}';

/// Solo el número, con punto de miles y coma decimal: `1.234,50`.
String formatAmount(num value) {
  final fixed = value.abs().toStringAsFixed(2);
  final whole = fixed.substring(0, fixed.length - 3);
  final cents = fixed.substring(fixed.length - 2);
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '${value < 0 ? '-' : ''}$grouped,$cents';
}

/// Cantidad compacta para tableros: `1,2K`, `3,4M` o el número sin decimales.
String compactNumber(num value) {
  String fixed(num v) => v.toStringAsFixed(1).replaceFirst('.', ',');
  if (value >= 1000000) return '${fixed(value / 1000000)}M';
  if (value >= 1000) return '${fixed(value / 1000)}K';
  return value % 1 == 0 ? value.toInt().toString() : fixed(value);
}
