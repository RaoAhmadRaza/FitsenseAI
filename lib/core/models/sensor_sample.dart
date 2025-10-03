import 'package:hive/hive.dart';

/// Lightweight sensor sample for dev/analytics collection.
/// Hive-only (no SQLite mirror). Can store either accelerometer, gyroscope,
/// or a combined sample (if upstream synchronizes streams).
/// type: 'accel' | 'gyro' | 'combined'
@HiveType(typeId: 17)
class SensorSample extends HiveObject {
  @HiveField(0)
  final DateTime timestamp;

  // Accelerometer (m/s^2). Nullable when not present.
  @HiveField(1)
  final double? ax;
  @HiveField(2)
  final double? ay;
  @HiveField(3)
  final double? az;

  // Gyroscope (rad/s). Nullable when not present.
  @HiveField(4)
  final double? gx;
  @HiveField(5)
  final double? gy;
  @HiveField(6)
  final double? gz;

  // Sample type discriminator
  @HiveField(7)
  final String type; // 'accel' | 'gyro' | 'combined'

  SensorSample({
    required this.timestamp,
    required this.type,
    this.ax,
    this.ay,
    this.az,
    this.gx,
    this.gy,
    this.gz,
  });

  SensorSample copyWith({
    DateTime? timestamp,
    String? type,
    double? ax,
    double? ay,
    double? az,
    double? gx,
    double? gy,
    double? gz,
  }) => SensorSample(
    timestamp: timestamp ?? this.timestamp,
    type: type ?? this.type,
    ax: ax ?? this.ax,
    ay: ay ?? this.ay,
    az: az ?? this.az,
    gx: gx ?? this.gx,
    gy: gy ?? this.gy,
    gz: gz ?? this.gz,
  );

  Map<String, Object?> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type,
    'ax': ax,
    'ay': ay,
    'az': az,
    'gx': gx,
    'gy': gy,
    'gz': gz,
  };

  static SensorSample fromMap(Map<String, Object?> m) => SensorSample(
    timestamp: DateTime.parse(m['timestamp'] as String),
    type: m['type'] as String,
    ax: (m['ax'] as num?)?.toDouble(),
    ay: (m['ay'] as num?)?.toDouble(),
    az: (m['az'] as num?)?.toDouble(),
    gx: (m['gx'] as num?)?.toDouble(),
    gy: (m['gy'] as num?)?.toDouble(),
    gz: (m['gz'] as num?)?.toDouble(),
  );
}

class SensorSampleAdapter extends TypeAdapter<SensorSample> {
  @override
  final int typeId = 17;

  @override
  SensorSample read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return SensorSample(
      timestamp: fields[0] as DateTime,
      type: fields[7] as String,
      ax: (fields[1] as num?)?.toDouble(),
      ay: (fields[2] as num?)?.toDouble(),
      az: (fields[3] as num?)?.toDouble(),
      gx: (fields[4] as num?)?.toDouble(),
      gy: (fields[5] as num?)?.toDouble(),
      gz: (fields[6] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, SensorSample obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.ax)
      ..writeByte(2)
      ..write(obj.ay)
      ..writeByte(3)
      ..write(obj.az)
      ..writeByte(4)
      ..write(obj.gx)
      ..writeByte(5)
      ..write(obj.gy)
      ..writeByte(6)
      ..write(obj.gz)
      ..writeByte(7)
      ..write(obj.type);
  }
}
