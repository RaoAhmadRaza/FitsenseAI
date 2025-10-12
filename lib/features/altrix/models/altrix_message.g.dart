// Manual Hive adapters for AltrixMessage (no codegen required).
part of 'altrix_message.dart';

class AltrixMessageAdapter extends TypeAdapter<AltrixMessage> {
  @override
  final int typeId = AltrixConstants.messageTypeId;

  @override
  AltrixMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return AltrixMessage(
      id: fields[0] as String,
      threadId: fields[1] as String,
      role: fields[2] as String,
      content: fields[3] as String,
      createdAt: fields[4] as DateTime,
      meta: (fields[5] as Map?)?.cast<String, dynamic>(),
      status: (fields[6] as String?) ?? 'success',
      tokensUsed: (fields[7] as int?) ?? 0,
      latencyMs: (fields[8] as int?) ?? 0,
      isGeminiResponse: (fields[9] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, AltrixMessage obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.threadId)
      ..writeByte(2)
      ..write(obj.role)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.meta)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.tokensUsed)
      ..writeByte(8)
      ..write(obj.latencyMs)
      ..writeByte(9)
      ..write(obj.isGeminiResponse);
  }
}
