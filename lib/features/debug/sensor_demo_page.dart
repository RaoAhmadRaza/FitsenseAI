import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/utils/logger.dart';

/// A lightweight debug page demonstrating access to device sensors.
/// Streams raw accelerometer & gyroscope events and shows them on screen while
/// also logging to console (useful starting point for rep counting logic).
class SensorDemoPage extends StatefulWidget {
  const SensorDemoPage({super.key});

  @override
  State<SensorDemoPage> createState() => _SensorDemoPageState();
}

class _SensorDemoPageState extends State<SensorDemoPage> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  AccelerometerEvent? _latestAccel;
  GyroscopeEvent? _latestGyro;

  @override
  void initState() {
    super.initState();

    // Subscribe to accelerometer
    _accelSub = accelerometerEventStream().listen(
      (event) {
        _latestAccel = event;
        logInfo(
          'ACCEL: x=${event.x.toStringAsFixed(2)} y=${event.y.toStringAsFixed(2)} z=${event.z.toStringAsFixed(2)}',
        );
        if (mounted) setState(() {});
      },
      onError: (e, st) {
        logError('Accelerometer stream error: $e', st);
      },
    );

    // Subscribe to gyroscope
    _gyroSub = gyroscopeEventStream().listen(
      (event) {
        _latestGyro = event;
        logInfo(
          'GYRO: x=${event.x.toStringAsFixed(2)} y=${event.y.toStringAsFixed(2)} z=${event.z.toStringAsFixed(2)}',
        );
        if (mounted) setState(() {});
      },
      onError: (e, st) {
        logError('Gyroscope stream error: $e', st);
      },
    );
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    super.dispose();
  }

  Widget _buildVectorRow(String label, double? x, double? y, double? z) {
    String format(double? v) => v == null ? '--' : v.toStringAsFixed(2);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('x: ${format(x)}'),
        Text('y: ${format(y)}'),
        Text('z: ${format(z)}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _latestAccel;
    final g = _latestGyro;

    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Sensor Streams',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildVectorRow('Accelerometer', a?.x, a?.y, a?.z),
            const SizedBox(height: 8),
            _buildVectorRow('Gyroscope', g?.x, g?.y, g?.z),
            const SizedBox(height: 24),
            const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              '- On emulators / desktop these values may stay zero or be unsupported.\n'
              '- Use a physical device for real readings.\n'
              '- This page can evolve into a rep counter by applying filters & peak detection.',
            ),
            const Spacer(),
            if (kDebugMode)
              TextButton(
                onPressed: () {
                  logWarn('Manual test button pressed.');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debug action executed.')),
                  );
                },
                child: const Text('Debug Action'),
              ),
          ],
        ),
      ),
    );
  }
}
