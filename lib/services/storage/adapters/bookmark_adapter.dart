import 'package:hive/hive.dart';
import '../../../shared/models/bookmark_model.dart';

/// Hive TypeAdapter for BookmarkModel
/// TypeId: 5
class BookmarkAdapter extends TypeAdapter<BookmarkModel> {
  @override
  final int typeId = 5;

  @override
  BookmarkModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    return BookmarkModel(
      lessonId: fields[0] as String,
      topicId: fields[1] as String,
      bookmarkedAt: fields[2] as DateTime,
      notes: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BookmarkModel obj) {
    writer
      ..writeByte(4) // Number of fields
      ..writeByte(0)
      ..write(obj.lessonId)
      ..writeByte(1)
      ..write(obj.topicId)
      ..writeByte(2)
      ..write(obj.bookmarkedAt)
      ..writeByte(3)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}