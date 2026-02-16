import 'package:hive/hive.dart';
import '../../../features/profile/data/models/user_profile_model.dart';

/// Hive TypeAdapter for UserProfileModel
/// TypeId: 6
///
/// Fields:
///   0: name (String)
///   1: profileImagePath (String?)
///   2: createdAt (int - millisecondsSinceEpoch)
///   3: updatedAt (int - millisecondsSinceEpoch)
///   4: lastLoginDate (int? - millisecondsSinceEpoch, nullable)
///   5: currentStreak (int)
///   6: loginDates (List<int> - millisecondsSinceEpoch)
class UserProfileAdapter extends TypeAdapter<UserProfileModel> {
  @override
  final int typeId = 6;

  @override
  UserProfileModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };

    // Parse loginDates from List<int> (backward-compatible)
    final rawLoginDates = fields.containsKey(6) ? fields[6] : null;
    final loginDates = <DateTime>[];
    if (rawLoginDates is List) {
      for (final ms in rawLoginDates) {
        if (ms is int) {
          loginDates.add(DateTime.fromMillisecondsSinceEpoch(ms));
        }
      }
    }

    return UserProfileModel(
      name: fields[0] as String,
      profileImagePath: fields[1] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[2] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      // Backward-compatible: default to null/0/[] if fields don't exist
      lastLoginDate: fields.containsKey(4) && fields[4] != null
          ? DateTime.fromMillisecondsSinceEpoch(fields[4] as int)
          : null,
      currentStreak: fields.containsKey(5) ? (fields[5] as int? ?? 0) : 0,
      loginDates: loginDates,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfileModel obj) {
    writer
      ..writeByte(7) // number of fields
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.profileImagePath)
      ..writeByte(2)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(3)
      ..write(obj.updatedAt.millisecondsSinceEpoch)
      ..writeByte(4)
      ..write(obj.lastLoginDate?.millisecondsSinceEpoch)
      ..writeByte(5)
      ..write(obj.currentStreak)
      ..writeByte(6)
      ..write(obj.loginDates.map((d) => d.millisecondsSinceEpoch).toList());
  }
}
