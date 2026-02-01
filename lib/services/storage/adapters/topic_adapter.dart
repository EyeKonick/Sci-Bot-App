import 'package:hive/hive.dart';
import '../../../shared/models/topic_model.dart';

/// Hive TypeAdapter for TopicModel
/// TypeId: 2
class TopicAdapter extends TypeAdapter<TopicModel> {
  @override
  final int typeId = 2;

  @override
  TopicModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    
    return TopicModel(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      iconName: fields[3] as String,
      colorHex: fields[4] as String,
      lessonIds: (fields[5] as List).cast<String>(),
      order: fields[6] as int,
      imageAsset: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TopicModel obj) {
    writer
      ..writeByte(8) // number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.iconName)
      ..writeByte(4)
      ..write(obj.colorHex)
      ..writeByte(5)
      ..write(obj.lessonIds)
      ..writeByte(6)
      ..write(obj.order)
      ..writeByte(7)
      ..write(obj.imageAsset);
  }
}