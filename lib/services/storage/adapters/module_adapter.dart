import 'package:hive/hive.dart';
import '../../../shared/models/module_model.dart';
import '../../../shared/models/module_type.dart';

/// Hive TypeAdapter for ModuleModel
/// TypeId: 0
class ModuleAdapter extends TypeAdapter<ModuleModel> {
  @override
  final int typeId = 0;

  @override
  ModuleModel read(BinaryReader reader) {
    return ModuleModel(
      id: reader.readString(),
      type: ModuleType.values[reader.readInt()],
      title: reader.readString(),
      content: reader.readString(),
      order: reader.readInt(),
      estimatedMinutes: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, ModuleModel obj) {
    writer.writeString(obj.id);
    writer.writeInt(obj.type.index);
    writer.writeString(obj.title);
    writer.writeString(obj.content);
    writer.writeInt(obj.order);
    writer.writeInt(obj.estimatedMinutes);
  }
}