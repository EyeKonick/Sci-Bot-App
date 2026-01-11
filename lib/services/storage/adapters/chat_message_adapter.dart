import 'package:hive/hive.dart';
import '../../../shared/models/chat_message_model.dart';

/// Hive TypeAdapter for ChatMessageModel
/// TypeId: 4
class ChatMessageAdapter extends TypeAdapter<ChatMessageModel> {
  @override
  final int typeId = 4;

  @override
  ChatMessageModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    
    return ChatMessageModel(
      id: fields[0] as String,
      text: fields[1] as String,
      sender: MessageSender.values[fields[2] as int],
      timestamp: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      lessonContext: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessageModel obj) {
    writer
      ..writeByte(5) // number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.sender.index)
      ..writeByte(3)
      ..write(obj.timestamp.millisecondsSinceEpoch)
      ..writeByte(4)
      ..write(obj.lessonContext);
  }
}