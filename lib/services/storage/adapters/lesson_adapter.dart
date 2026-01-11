import 'package:hive/hive.dart';
import '../../../shared/models/lesson_model.dart';
import '../../../shared/models/module_model.dart';

/// Hive TypeAdapter for LessonModel
/// TypeId: 1
class LessonAdapter extends TypeAdapter<LessonModel> {
  @override
  final int typeId = 1;

  @override
  LessonModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    
    return LessonModel(
      id: fields[0] as String,
      topicId: fields[1] as String,
      title: fields[2] as String,
      description: fields[3] as String,
      modules: (fields[4] as List).cast<ModuleModel>(),
      estimatedMinutes: fields[5] as int,
      imageUrl: fields[6] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, LessonModel obj) {
    writer
      ..writeByte(7) // number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.topicId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.modules)
      ..writeByte(5)
      ..write(obj.estimatedMinutes)
      ..writeByte(6)
      ..write(obj.imageUrl);
  }
}