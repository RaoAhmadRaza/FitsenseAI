// Manual Hive adapters for AltrixThread (no codegen required).
part of 'altrix_thread.dart';

class AltrixThreadAdapter extends TypeAdapter<AltrixThread> {
  @override
  final int typeId = AltrixConstants.threadTypeId;

  @override
  AltrixThread read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return AltrixThread(
      id: fields[0] as String,
      title: fields[1] as String,
      createdAt: fields[2] as DateTime,
      updatedAt: fields[3] as DateTime,
      messageCount: fields[4] as int,
      archived: (fields[5] as bool?) ?? false,
      pinned: (fields[6] as bool?) ?? false,
      model: (fields[7] as String?) ?? 'gemini-2.0-flash',
      promptCount: (fields[8] as int?) ?? 0,
      avgLatencyMs: (fields[9] as double?) ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, AltrixThread obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.updatedAt)
      ..writeByte(4)
      ..write(obj.messageCount)
      ..writeByte(5)
      ..write(obj.archived)
      ..writeByte(6)
      ..write(obj.pinned)
      ..writeByte(7)
      ..write(obj.model)
      ..writeByte(8)
      ..write(obj.promptCount)
      ..writeByte(9)
      ..write(obj.avgLatencyMs);
  }
}
