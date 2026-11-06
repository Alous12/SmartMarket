import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/store_model.dart';
import 'package:smartmarket/features/store_navigation/domain/services/pedestrian_tracker.dart';
import 'package:smartmarket/features/store_navigation/domain/services/step_detector.dart';
import 'package:smartmarket/features/store_navigation/domain/services/yaw_tracker.dart';

const _gravity = 9.81;
const _sampleMs = 20;

final _start = DateTime(2026);

DateTime _at(int sample) =>
    _start.add(Duration(milliseconds: sample * _sampleMs));

/// Simula [seconds] de caminata a [stepsPerSecond], con el teléfono en la mano.
int _walk(
  StepDetector detector, {
  required double seconds,
  double stepsPerSecond = 1.8,
  double amplitude = 2.5,
}) {
  var steps = 0;
  final samples = (seconds * 1000 / _sampleMs).round();
  for (var i = 0; i < samples; i++) {
    final t = i * _sampleMs / 1000;
    final bounce = amplitude * math.sin(2 * math.pi * stepsPerSecond * t);
    steps += detector.add(0.4, 1.2, _gravity + bounce, _at(i));
  }
  return steps;
}

StoreRouteNode _node(
  String id,
  double x,
  double z, [
  List<String> neighbors = const [],
]) => StoreRouteNode(id: id, x: x, y: 0, z: z, neighbors: neighbors);

/// Diez metros hacia +X y luego diez hacia -Z (giro a la izquierda vista arriba).
final _lRoute = [_node('a', 0, 0), _node('b', 10, 0), _node('c', 10, -10)];

/// Pasillo paralelo a 3,8 m, separado de la ruta por un estante.
final _shelfMap = [
  _node('a', 0, 0, ['b']),
  _node('b', 10, 0, ['c']),
  _node('c', 10, -10),
  _node('d', 0, -3.8, ['e']),
  _node('e', 8, -3.8),
];

const _left = math.pi / 2;

PedestrianTracker _tracker({List<StoreRouteNode>? walkable}) =>
    PedestrianTracker(route: _lRoute, walkable: walkable ?? _lRoute);

void _steps(PedestrianTracker tracker, int count, {double limit = 20}) {
  for (var i = 0; i < count; i++) {
    tracker.step(limit: limit);
  }
}

/// Dirección en el mapa que corresponde al giro del muñeco.
double _facing(PedestrianTracker tracker) => tracker.pose.rotation;

void main() {
  group('Detector de pasos', () {
    test('cuenta los pasos de una caminata normal', () {
      expect(_walk(StepDetector(), seconds: 10), inInclusiveRange(16, 19));
    });

    test('cuenta una caminata lenta y suave', () {
      final steps = _walk(
        StepDetector(),
        seconds: 10,
        stepsPerSecond: 1.2,
        amplitude: 1.8,
      );

      expect(steps, inInclusiveRange(10, 13));
    });

    test('cuenta una caminata muy suave con el teléfono en la mano', () {
      final steps = _walk(
        StepDetector(),
        seconds: 10,
        stepsPerSecond: 1.6,
        amplitude: 0.8,
      );

      expect(steps, inInclusiveRange(13, 17));
    });

    test('se adapta si después la persona camina más suave', () {
      final detector = StepDetector();
      _walk(detector, seconds: 5, amplitude: 3);
      var steps = 0;
      for (var i = 0; i < 500; i++) {
        final t = i * _sampleMs / 1000;
        final bounce = 0.8 * math.sin(2 * math.pi * 1.6 * t);
        steps += detector.add(0, 0, _gravity + bounce, _at(1000 + i));
      }

      expect(steps, inInclusiveRange(12, 17));
    });

    test('quieto con ruido del sensor no cuenta pasos', () {
      final detector = StepDetector();
      final random = math.Random(1);
      var steps = 0;
      for (var i = 0; i < 1000; i++) {
        final noise = (random.nextDouble() - 0.5) * 0.6;
        steps += detector.add(0, 0, _gravity + noise, _at(i));
      }

      expect(steps, 0);
    });

    test('un golpe aislado no cuenta como paso', () {
      final detector = StepDetector();
      var steps = 0;
      for (var i = 0; i < 300; i++) {
        final bump = i >= 100 && i < 106 ? 8.0 : 0.0;
        steps += detector.add(0, 0, _gravity + bump, _at(i));
      }

      expect(steps, 0);
    });

    test('sacudir el teléfono no cuenta como caminar', () {
      final steps = _walk(StepDetector(), seconds: 5, amplitude: 18);

      expect(steps, 0);
    });

    test('no importa cómo se sostenga el teléfono', () {
      final detector = StepDetector();
      var steps = 0;
      for (var i = 0; i < 500; i++) {
        final t = i * _sampleMs / 1000;
        final value = _gravity + 2.5 * math.sin(2 * math.pi * 1.8 * t);
        steps += detector.add(value, 0, 0, _at(i));
      }

      expect(steps, inInclusiveRange(16, 19));
    });
  });

  group('Orientación', () {
    double turn({required List<double> up, required List<double> rotation}) {
      final tracker = YawTracker();
      for (var i = 0; i < 20; i++) {
        tracker.addAcceleration(up[0], up[1], up[2]);
      }
      for (var i = 0; i <= 50; i++) {
        tracker.addRotation(rotation[0], rotation[1], rotation[2], _at(i));
      }
      return tracker.reading!.value;
    }

    YawTracker level() {
      final tracker = YawTracker();
      for (var i = 0; i < 20; i++) {
        tracker.addAcceleration(0, 0, _gravity);
      }
      return tracker;
    }

    test('mide un giro con el teléfono plano', () {
      expect(
        turn(up: [0, 0, _gravity], rotation: [0, 0, _left]),
        closeTo(_left, 0.01),
      );
    });

    test('mide el mismo giro con el teléfono vertical', () {
      expect(
        turn(up: [0, _gravity, 0], rotation: [0, _left, 0]),
        closeTo(_left, 0.01),
      );
    });

    test('ignora la rotación que no es alrededor de la vertical', () {
      expect(
        turn(up: [0, 0, _gravity], rotation: [1, 1, 0]),
        closeTo(0, 0.01),
      );
    });

    test('no inventa un giro si el sensor se atrasa', () {
      final tracker = YawTracker()..addAcceleration(0, 0, _gravity);
      tracker.addRotation(0, 0, 1, _start);
      tracker.addRotation(0, 0, 1, _start.add(const Duration(seconds: 5)));

      expect(tracker.reading, isNull);
    });

    test('sin giroscopio ni brújula no hay orientación', () {
      expect((YawTracker()..addAcceleration(0, 0, _gravity)).reading, isNull);
    });

    /// Campo terrestre visto por un teléfono plano girado [yaw] a la izquierda.
    List<double> field(double yaw) => [
      30 * math.sin(yaw),
      30 * math.cos(yaw),
      -20,
    ];

    test('la brújula define el norte como cero', () {
      final reading = (level()..addMagnetic(0, 30, -20)).reading!;

      expect(reading.absolute, isTrue);
      expect(reading.value, closeTo(0, 1e-9));
    });

    test('la brújula distingue los cuatro puntos cardinales', () {
      for (final angle in [_left, math.pi, -_left]) {
        final [x, y, z] = field(angle);
        final reading = (level()..addMagnetic(x, y, z)).reading!;

        expect(math.cos(reading.value - angle), closeTo(1, 1e-9));
      }
    });

    test('solo con giroscopio la orientación no es absoluta', () {
      final tracker = level();
      tracker.addRotation(0, 0, 0, _at(0));
      tracker.addRotation(0, 0, 0, _at(1));

      expect(tracker.reading!.absolute, isFalse);
    });

    test('la primera lectura de la brújula fija el norte aunque ya haya giros', () {
      final tracker = level();
      tracker.addRotation(0, 0, 1, _at(0));
      tracker.addRotation(0, 0, 1, _at(5));
      final [x, y, z] = field(_left);

      tracker.addMagnetic(x, y, z);

      expect(tracker.reading!.value, closeTo(_left, 1e-9));
    });

    test('sin giroscopio la brújula sigue los giros', () {
      final tracker = level()..addMagnetic(0, 30, -20);

      for (var i = 0; i < 60; i++) {
        final [x, y, z] = field(_left);
        tracker.addMagnetic(x, y, z);
      }

      expect(tracker.reading!.value, closeTo(_left, 0.02));
    });

    test('la brújula mide igual con el teléfono vertical', () {
      final flat = level()..addMagnetic(0, 30, -20);
      final upright = YawTracker();
      for (var i = 0; i < 20; i++) {
        upright.addAcceleration(0, _gravity, 0);
      }
      // De pie, el norte que antes estaba hacia +Y queda detrás de la pantalla.
      upright.addMagnetic(0, -20, -30);

      expect(upright.reading!.value, closeTo(flat.reading!.value, 0.01));
    });

    test('la brújula corrige la deriva del giroscopio', () {
      final tracker = level();
      tracker.addRotation(0, 0, 0, _at(0));
      tracker.addRotation(0, 0, 0, _at(1));
      tracker.addMagnetic(0, 30, -20);

      // Quieto, pero el giroscopio deriva 3 grados por segundo durante 20 segundos.
      const drift = 3 * math.pi / 180;
      for (var i = 2; i < 1000; i++) {
        tracker.addRotation(0, 0, drift, _at(i));
        tracker.addMagnetic(0, 30, -20);
      }

      expect(tracker.reading!.value.abs(), lessThan(20 * drift * 0.6));
    });

    test('ignora la brújula cerca de metal o imanes', () {
      final tracker = level()..addMagnetic(0, 30, -20);

      for (var i = 0; i < 60; i++) {
        tracker.addMagnetic(200, 0, 0);
      }

      expect(tracker.reading!.value, closeTo(0, 1e-9));
    });
  });

  group('Puntos cardinales del mapa', () {
    const north = 0.0, west = _left, south = math.pi, east = -_left;

    (double, double) walk(double yaw, {double northDegrees = 0}) {
      final tracker = PedestrianTracker(
        route: [_node('a', 0, 0), _node('b', 10, 0)],
        walkable: const [],
        northDegrees: northDegrees,
      )..updateYaw(yaw, absolute: true);
      final start = tracker.pose;
      // Se mide un paso sin pasillos que lo limiten.
      _steps(tracker, 1);
      return (tracker.pose.x - start.x, tracker.pose.z - start.z);
    }

    test('mirar al norte camina hacia arriba del mapa', () {
      final (x, z) = walk(north);

      expect(z, lessThan(0));
      expect(x, closeTo(0, 1e-9));
    });

    test('mirar al este camina hacia la derecha del mapa', () {
      final (x, z) = walk(east);

      expect(x, greaterThan(0));
      expect(z, closeTo(0, 1e-9));
    });

    test('mirar al sur camina hacia abajo del mapa', () {
      final (x, z) = walk(south);

      expect(z, greaterThan(0));
      expect(x, closeTo(0, 1e-9));
    });

    test('mirar al oeste camina hacia la izquierda del mapa', () {
      final (x, z) = walk(west);

      expect(x, lessThan(0));
      expect(z, closeTo(0, 1e-9));
    });

    test('la orientación no depende de hacia dónde sale la ruta', () {
      final tracker = _tracker()..updateYaw(north, absolute: true);

      expect(_facing(tracker), closeTo(math.pi, 1e-9));
    });

    test('un local girado respecto del norte ajusta el mapa', () {
      // Si el norte real queda a la derecha del mapa, mirar al norte va hacia +X.
      final (x, z) = walk(north, northDegrees: 90);

      expect(x, greaterThan(0));
      expect(z, closeTo(0, 1e-9));
    });

    test('la corrección manual se mantiene sobre la brújula', () {
      final tracker = _tracker()..updateYaw(1, absolute: true);

      tracker.recenter();
      tracker.updateYaw(1, absolute: true);
      _steps(tracker, 1);

      expect(tracker.pose.x, closeTo(0.7, 1e-9));
    });
  });

  group('Movimiento real', () {
    test('al empezar mira hacia donde sale la ruta', () {
      final tracker = _tracker()..updateYaw(1.3);

      expect(_facing(tracker), closeTo(_left, 1e-9));
    });

    test('el muñeco gira con la persona aunque esté quieta', () {
      final tracker = _tracker()..updateYaw(0);

      tracker.updateYaw(_left);

      expect(_facing(tracker), closeTo(math.pi, 1e-9));
      expect(tracker.pose.x, 0);
    });

    test('cada paso avanza hacia donde mira la persona', () {
      final tracker = _tracker()..updateYaw(0);

      _steps(tracker, 2);

      expect(tracker.pose.x, closeTo(1.4, 1e-9));
      expect(tracker.pose.z, closeTo(0, 1e-9));
    });

    test('girar a la izquierda en la esquina sigue por el otro pasillo', () {
      final tracker = _tracker()..updateYaw(0);
      _steps(tracker, 15);
      expect(tracker.pose.x, closeTo(10.5, 1e-9));

      tracker.updateYaw(_left);
      _steps(tracker, 3);

      expect(tracker.pose.z, closeTo(-2.1, 1e-9));
    });

    test('puede volver atrás por el pasillo', () {
      final tracker = _tracker()..updateYaw(0);
      _steps(tracker, 6);

      tracker.updateYaw(math.pi);
      _steps(tracker, 3);

      expect(tracker.pose.x, closeTo(2.1, 1e-9));
    });

    test('no atraviesa un estante', () {
      final tracker = _tracker(walkable: _shelfMap)..updateYaw(0);
      _steps(tracker, 5);

      tracker.updateYaw(_left);
      _steps(tracker, 20);

      expect(tracker.pose.z, closeTo(-1, 1e-9));
    });

    test('al chocar con un estante se desliza por su borde', () {
      final tracker = _tracker(walkable: _shelfMap)..updateYaw(0);
      _steps(tracker, 3);

      // Camina en diagonal contra el estante.
      tracker.updateYaw(_left / 2);
      _steps(tracker, 5);

      expect(tracker.pose.z, closeTo(-1, 1e-9));
      expect(tracker.pose.x, greaterThan(4));
    });

    test('el botón alinea la dirección con la ruta', () {
      final tracker = _tracker()..updateYaw(0);
      tracker.updateYaw(2);

      tracker.recenter();
      _steps(tracker, 1);

      expect(tracker.pose.x, closeTo(0.7, 1e-9));
    });

    test('sin orientación sigue la ruta con los pasos', () {
      final tracker = _tracker();

      _steps(tracker, 20);

      expect(tracker.walked, closeTo(14, 1e-9));
      expect(tracker.pose.z, closeTo(-4, 1e-9));
    });

    test('una ruta sin tramos no falla', () {
      final tracker = PedestrianTracker(
        route: [_node('a', 3, 3)],
        walkable: const [],
      )..updateYaw(0);

      _steps(tracker, 2);

      expect(tracker.walked, 0);
    });
  });

  group('La línea se consume', () {
    test('al avanzar por la ruta', () {
      final tracker = _tracker()..updateYaw(0);

      _steps(tracker, 5);

      expect(tracker.walked, closeTo(3.5, 1e-9));
    });

    test('no se consume al retroceder', () {
      final tracker = _tracker()..updateYaw(0);
      _steps(tracker, 6);

      tracker.updateYaw(math.pi);
      _steps(tracker, 3);

      expect(tracker.walked, closeTo(4.2, 1e-9));
    });

    test('no se consume si se aleja por otro pasillo', () {
      final map = [
        _node('a', 0, 0, ['b', 'x']),
        _node('b', 10, 0, ['c']),
        _node('c', 10, -10),
        _node('x', 0, 10),
      ];
      final tracker = _tracker(walkable: map)..updateYaw(0);

      tracker.updateYaw(-_left);
      _steps(tracker, 10);

      expect(tracker.pose.z, closeTo(7, 1e-9));
      expect(tracker.walked, closeTo(0, 1e-9));
    });

    test('no pasa de la próxima parada', () {
      final tracker = _tracker()..updateYaw(0);

      _steps(tracker, 10, limit: 2);

      expect(tracker.walked, 2);
      expect(tracker.pose.x, closeTo(7, 1e-9));
    });

    test('confirmar una parada ubica allí al muñeco', () {
      final tracker = _tracker()..updateYaw(0);

      tracker.moveTo(15);

      expect(tracker.pose.x, closeTo(10, 1e-9));
      expect(tracker.pose.z, closeTo(-5, 1e-9));
    });
  });
}
