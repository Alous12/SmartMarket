import 'dart:math' as math;

/// Orientación en radianes, positiva en sentido antihorario visto desde arriba.
class YawReading {
  const YawReading(this.value, {required this.absolute});

  final double value;

  /// Si es verdadero, 0 es el norte. Si no, solo importa cuánto cambia.
  final bool absolute;
}

/// Mide la orientación de la persona alrededor de la vertical. El acelerómetro
/// indica dónde está "arriba", la brújula dónde está el norte y el giroscopio da los
/// giros al instante entre lecturas de la brújula, que es lenta y ruidosa. Funciona
/// en cualquier posición del teléfono.
class YawTracker {
  /// Si el giroscopio se atrasa no se integra el hueco: inventaría un giro.
  static const _maxGap = Duration(milliseconds: 200);

  /// Campo magnético terrestre esperado (µT): fuera de esto hay metal o imanes
  /// cerca y la lectura no sirve.
  static const _minField = 15.0;
  static const _maxField = 90.0;

  /// Peso de la brújula por muestra: lento, para no copiar sus perturbaciones.
  static const _compassPull = 0.002;

  /// Las primeras muestras pesan más, para asentarse rápido en el norte real.
  static const _settlingPull = 0.05;
  static const _settlingSamples = 100;

  double? _upX;
  double? _upY;
  double? _upZ;
  double _yaw = 0;
  bool _hasRotation = false;
  bool _hasCompass = false;
  int _compassSamples = 0;
  DateTime? _lastRotation;

  /// Null sin giroscopio ni brújula.
  YawReading? get reading => _hasRotation || _hasCompass
      ? YawReading(_yaw, absolute: _hasCompass)
      : null;

  void addAcceleration(double x, double y, double z) {
    _upX = (_upX ?? x) + 0.1 * (x - (_upX ?? x));
    _upY = (_upY ?? y) + 0.1 * (y - (_upY ?? y));
    _upZ = (_upZ ?? z) + 0.1 * (z - (_upZ ?? z));
  }

  void addRotation(double x, double y, double z, DateTime time) {
    final last = _lastRotation;
    _lastRotation = time;
    final upX = _upX, upY = _upY, upZ = _upZ;
    if (upX == null || upY == null || upZ == null || last == null) return;
    final length = math.sqrt(upX * upX + upY * upY + upZ * upZ);
    final elapsed = time.difference(last);
    if (length == 0 || elapsed > _maxGap || elapsed.isNegative) return;
    final rate = (x * upX + y * upY + z * upZ) / length;
    _yaw += rate * elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    _hasRotation = true;
  }

  void addMagnetic(double x, double y, double z) {
    final compass = _compassYaw(x, y, z);
    if (compass == null) return;
    if (!_hasCompass) {
      _yaw = compass;
      _hasCompass = true;
      return;
    }
    final settling = _compassSamples++ < _settlingSamples;
    // Sin giroscopio la brújula manda, suavizada porque es ruidosa.
    final pull = !_hasRotation
        ? 0.2
        : settling
        ? _settlingPull
        : _compassPull;
    _yaw += pull * _wrap(compass - _yaw);
  }

  /// Rumbo del teléfono respecto del norte magnético, ya compensada su inclinación.
  double? _compassYaw(double x, double y, double z) {
    final upX = _upX, upY = _upY, upZ = _upZ;
    if (upX == null || upY == null || upZ == null) return null;
    final field = math.sqrt(x * x + y * y + z * z);
    if (field < _minField || field > _maxField) return null;
    final upLength = math.sqrt(upX * upX + upY * upY + upZ * upZ);
    if (upLength == 0) return null;
    final ux = upX / upLength, uy = upY / upLength, uz = upZ / upLength;

    // Este = campo × arriba; norte = arriba × este.
    final eastX = y * uz - z * uy;
    final eastY = z * ux - x * uz;
    final eastZ = x * uy - y * ux;
    final northX = uy * eastZ - uz * eastY;
    final northY = uz * eastX - ux * eastZ;
    final northZ = ux * eastY - uy * eastX;

    // Hacia dónde mira la persona: la punta del teléfono si está plano, la cámara
    // trasera si está de pie. Esta suma da lo mismo en cualquier inclinación.
    const forwardY = 1.0, forwardZ = -1.0;
    final along = forwardY * uy + forwardZ * uz;
    final flatX = -along * ux;
    final flatY = forwardY - along * uy;
    final flatZ = forwardZ - along * uz;

    final towardEast = flatX * eastX + flatY * eastY + flatZ * eastZ;
    final towardNorth = flatX * northX + flatY * northY + flatZ * northZ;
    if (towardEast == 0 && towardNorth == 0) return null;
    return -math.atan2(towardEast, towardNorth);
  }

  static double _wrap(double angle) => math.atan2(math.sin(angle), math.cos(angle));
}
