import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Lectura de un sensor de tres ejes.
class MotionSample {
  const MotionSample(this.x, this.y, this.z, this.time);

  final double x;
  final double y;
  final double z;
  final DateTime time;
}

/// Sensores de movimiento del teléfono. Si el teléfono no tiene alguno, su
/// stream termina con un error.
abstract interface class MotionSensors {
  Stream<MotionSample> get acceleration;
  Stream<MotionSample> get rotation;
  Stream<MotionSample> get magnetic;
}

class DeviceMotionSensors implements MotionSensors {
  const DeviceMotionSensors();

  @override
  Stream<MotionSample> get acceleration =>
      accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).map(
        (event) => MotionSample(event.x, event.y, event.z, event.timestamp),
      );

  @override
  Stream<MotionSample> get rotation =>
      gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval).map(
        (event) => MotionSample(event.x, event.y, event.z, event.timestamp),
      );

  @override
  Stream<MotionSample> get magnetic =>
      magnetometerEventStream(samplingPeriod: SensorInterval.gameInterval).map(
        (event) => MotionSample(event.x, event.y, event.z, event.timestamp),
      );
}

final motionSensorsProvider = Provider<MotionSensors>(
  (ref) => const DeviceMotionSensors(),
);
