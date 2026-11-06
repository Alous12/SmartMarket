import 'dart:math' as math;

/// Cuenta pasos con el acelerómetro. Usa la magnitud de la aceleración, así que
/// no importa cómo se sostenga el teléfono.
class StepDetector {
  /// El umbral se adapta a cada persona: es la mitad del impulso de sus últimos
  /// pasos, dentro de estos límites (m/s²). Una mano quieta no llega al mínimo.
  static const _minThreshold = 0.35;
  static const _maxThreshold = 1.2;

  static const _initialPeak = 1.0;

  /// Más que esto no es un paso, es una sacudida del teléfono.
  static const _maxPeak = 9.0;

  /// Más rápido que esto es rebote del mismo paso; más lento, gente detenida.
  static const _minInterval = Duration(milliseconds: 280);
  static const _maxInterval = Duration(milliseconds: 1600);

  double? _smoothed;
  double? _baseline;
  double _typicalPeak = _initialPeak;
  double? _peak;
  DateTime? _peakTime;
  DateTime? _lastStep;
  bool _pending = false;

  double get _threshold =>
      (_typicalPeak / 2).clamp(_minThreshold, _maxThreshold);

  /// Devuelve los pasos confirmados por esta muestra. Un impulso aislado no se
  /// cuenta hasta que llega otro con ritmo de caminata: así un golpe o sacar el
  /// teléfono del bolsillo no mueven al muñeco.
  int add(double x, double y, double z, DateTime time) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    final smoothed = (_smoothed ??= magnitude);
    _smoothed = smoothed + 0.3 * (magnitude - smoothed);
    final baseline = (_baseline ??= magnitude);
    _baseline = baseline + 0.02 * (magnitude - baseline);
    final signal = _smoothed! - _baseline!;

    // Tras una pausa se olvida el ritmo anterior: si no, un paso suave después de
    // otros fuertes no llegaría nunca al umbral.
    final last = _lastStep;
    if (last != null && time.difference(last) > _maxInterval) {
      _typicalPeak = _initialPeak;
    }

    final peak = _peak;
    if (peak == null) {
      if (signal >= _threshold) {
        _peak = signal;
        _peakTime = time;
      }
      return 0;
    }
    if (signal > peak) _peak = signal;
    if (signal >= 0) return 0;

    // El impulso terminó: recién ahora se conoce su tamaño.
    _peak = null;
    return _finishPeak(peak, _peakTime!);
  }

  int _finishPeak(double peak, DateTime time) {
    if (peak > _maxPeak) return 0;
    final last = _lastStep;
    final elapsed = last == null ? null : time.difference(last);
    if (elapsed != null && elapsed < _minInterval) return 0;
    _lastStep = time;
    _typicalPeak += 0.3 * (peak - _typicalPeak);
    if (elapsed == null || elapsed > _maxInterval) {
      _pending = true;
      return 0;
    }
    final steps = _pending ? 2 : 1;
    _pending = false;
    return steps;
  }
}
