import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/motion_sensors.dart';
import '../../domain/services/step_detector.dart';
import '../../domain/services/yaw_tracker.dart';

/// Escucha los sensores solo mientras hay una ruta en curso y la app está a la
/// vista, para no gastar batería. Sin sensores la ruta sigue funcionando con los
/// botones de cada parada.
class RouteMotionController {
  RouteMotionController({
    required this.sensors,
    required this.onSteps,
    required this.onYaw,
    required this.onUnavailable,
  }) {
    _lifecycle = AppLifecycleListener(
      onHide: () => _setVisible(false),
      onShow: () => _setVisible(true),
    );
  }

  /// Avisos de giro por segundo como máximo: el visor interpola el resto.
  static const _yawInterval = Duration(milliseconds: 80);

  /// Giro mínimo para avisar, en radianes (un grado).
  static const _minTurn = 0.017;

  final MotionSensors sensors;

  /// Pasos detectados y orientación del teléfono (null sin giroscopio ni brújula).
  final void Function(int steps, YawReading? yaw) onSteps;

  /// La persona giró, aunque esté quieta.
  final ValueChanged<YawReading> onYaw;

  /// El teléfono no puede detectar pasos.
  final VoidCallback onUnavailable;

  late final AppLifecycleListener _lifecycle;
  final _tracker = YawTracker();
  StreamSubscription<MotionSample>? _acceleration;
  StreamSubscription<MotionSample>? _rotation;
  StreamSubscription<MotionSample>? _magnetic;
  bool _wanted = false;
  bool _visible = true;
  bool _unavailable = false;
  DateTime? _lastYawTime;
  double? _lastYaw;

  set active(bool value) {
    if (_wanted == value) return;
    _wanted = value;
    _sync();
  }

  void _setVisible(bool value) {
    _visible = value;
    _sync();
  }

  void _sync() {
    if (_wanted && _visible && !_unavailable) {
      _listen();
    } else {
      _cancel();
    }
  }

  void _listen() {
    if (_acceleration != null) return;
    final detector = StepDetector();
    _acceleration = sensors.acceleration.listen(
      (sample) {
        _tracker.addAcceleration(sample.x, sample.y, sample.z);
        final steps = detector.add(sample.x, sample.y, sample.z, sample.time);
        if (steps > 0) onSteps(steps, _tracker.reading);
      },
      onError: (Object error) {
        _unavailable = true;
        _cancel();
        onUnavailable();
      },
      cancelOnError: true,
    );
    _rotation = sensors.rotation.listen(
      (sample) {
        _tracker.addRotation(sample.x, sample.y, sample.z, sample.time);
        _reportYaw(sample.time);
      },
      // Muchos teléfonos económicos no tienen giroscopio: queda la brújula.
      onError: (Object error) {},
      cancelOnError: true,
    );
    _magnetic = sensors.magnetic.listen(
      (sample) {
        _tracker.addMagnetic(sample.x, sample.y, sample.z);
        _reportYaw(sample.time);
      },
      onError: (Object error) {},
      cancelOnError: true,
    );
  }

  void _reportYaw(DateTime time) {
    final reading = _tracker.reading;
    final last = _lastYawTime;
    if (reading == null) return;
    if (last != null && time.difference(last) < _yawInterval) return;
    final previous = _lastYaw;
    if (previous != null && (reading.value - previous).abs() < _minTurn) return;
    _lastYawTime = time;
    _lastYaw = reading.value;
    onYaw(reading);
  }

  void _cancel() {
    unawaited(_acceleration?.cancel());
    unawaited(_rotation?.cancel());
    unawaited(_magnetic?.cancel());
    _acceleration = null;
    _rotation = null;
    _magnetic = null;
  }

  void dispose() {
    _cancel();
    _lifecycle.dispose();
  }
}
