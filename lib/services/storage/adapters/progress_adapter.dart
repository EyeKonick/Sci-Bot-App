import 'package:hive/hive.dart';
import '../../../shared/models/progress_model.dart';

/// Hive TypeAdapter for ProgressModel
/// TypeId: 3
class ProgressAdapter extends TypeAdapter<ProgressModel> {
  @override
  final int typeId = 3;

  @override
  ProgressModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    
    return ProgressModel(
      lessonId: fields[0] as String,
      completedModuleIds: (fields[1] as List).cast<String>().toSet(),
      lastAccessed: DateTime.fromMillisecondsSinceEpoch(fields[2] as int),
      completedAt: fields[3] != null 
          ? DateTime.fromMillisecondsSinceEpoch(fields[3] as int)
          : null,
    );
  }

  @override
  void write(BinaryWriter writer, ProgressModel obj) {
    writer
      ..writeByte(4) // number of fields
      ..writeByte(0)
      ..write(obj.lessonId)
      ..writeByte(1)
      ..write(obj.completedModuleIds.toList())
      ..writeByte(2)
      ..write(obj.lastAccessed.millisecondsSinceEpoch)
      ..writeByte(3)
      ..write(obj.completedAt?.millisecondsSinceEpoch);
  }
}