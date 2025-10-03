// lib/features/sensors/data/sensor_repository.dart
// Repository abstraction for device sensors (accelerometer, gyroscope).
// Keeps UI and business logic decoupled from sensors_plus so we can mock easily.

import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../core/utils/logger.dart';

/// Abstraction for reading device motion sensors.
abstract class SensorRepository {
  /// A broadcast stream of accelerometer events.
  Stream<AccelerometerEvent> get accelerometer$;

  /// A broadcast stream of gyroscope events.
  Stream<GyroscopeEvent> get gyroscope$;
}

/// Default implementation backed by sensors_plus.
class SensorRepositoryImpl implements SensorRepository {
  /// When true, logs sensor readings (may be noisy). Useful for dev/debug.
  final bool debugLog;

  const SensorRepositoryImpl({this.debugLog = false});

  @override
  Stream<AccelerometerEvent> get accelerometer$ {
    Stream<AccelerometerEvent> s = accelerometerEvents.handleError(
      (e, st) => logError('Accelerometer stream error: $e', st),
    );
    if (!debugLog) return s;
    return s.transform(
      StreamTransformer.fromHandlers(
        handleData: (event, sink) {
          logInfo(
            'accel x=${event.x.toStringAsFixed(3)} y=${event.y.toStringAsFixed(3)} z=${event.z.toStringAsFixed(3)}',
          );
          sink.add(event);
        },
        handleError: (e, st, sink) {
          // Already logged above via handleError; swallow.
        },
      ),
    );
  }

  @override
  Stream<GyroscopeEvent> get gyroscope$ {
    Stream<GyroscopeEvent> s = gyroscopeEvents.handleError(
      (e, st) => logError('Gyroscope stream error: $e', st),
    );
    if (!debugLog) return s;
    return s.transform(
      StreamTransformer.fromHandlers(
        handleData: (event, sink) {
          logInfo(
            'gyro x=${event.x.toStringAsFixed(3)} y=${event.y.toStringAsFixed(3)} z=${event.z.toStringAsFixed(3)}',
          );
          sink.add(event);
        },
        handleError: (e, st, sink) {
          // Already logged above via handleError; swallow.
        },
      ),
    );
  }
}
