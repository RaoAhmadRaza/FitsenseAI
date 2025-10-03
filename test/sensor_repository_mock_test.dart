import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:ai_fitness_tracker/features/sensors/data/sensor_repository.dart';

class FakeSensorRepository implements SensorRepository {
  final StreamController<AccelerometerEvent> accel = StreamController.broadcast();
  final StreamController<GyroscopeEvent> gyro = StreamController.broadcast();

  @override
  Stream<AccelerometerEvent> get accelerometer$ => accel.stream;

  @override
  Stream<GyroscopeEvent> get gyroscope$ => gyro.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SensorRepository mock stream injection works', () async {
    final fake = FakeSensorRepository();
    final accelEvents = <AccelerometerEvent>[];
    final gyroEvents = <GyroscopeEvent>[];

    final sub1 = fake.accelerometer$.listen(accelEvents.add);
    final sub2 = fake.gyroscope$.listen(gyroEvents.add);

  fake.accel.add(AccelerometerEvent(1.0, 2.0, 3.0, DateTime.now()));
  fake.gyro.add(GyroscopeEvent(0.1, 0.2, 0.3, DateTime.now()));

    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(accelEvents.length, 1);
    expect(gyroEvents.length, 1);

    await sub1.cancel();
    await sub2.cancel();
    await fake.accel.close();
    await fake.gyro.close();
  });
}
