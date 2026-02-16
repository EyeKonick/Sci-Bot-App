/// User profile model for storing student name and profile picture
/// Stored in Hive with typeId: 6 (via UserProfileAdapter)
class UserProfileModel {
  final String name;
  final String? profileImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Streak tracking fields
  final DateTime? lastLoginDate;
  final int currentStreak;
  final List<DateTime> loginDates; // Last 30 days of login history

  const UserProfileModel({
    required this.name,
    this.profileImagePath,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginDate,
    this.currentStreak = 0,
    this.loginDates = const [],
  });

  /// Validation: Check if name meets length requirements (2-20 characters)
  bool get isNameValid =>
      name.trim().isNotEmpty &&
      name.trim().length >= 2 &&
      name.trim().length <= 20;

  /// Check if profile has a picture
  bool get hasProfilePicture =>
      profileImagePath != null &&
      profileImagePath!.isNotEmpty;

  /// Factory constructor from JSON
  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      name: json['name'] as String,
      profileImagePath: json['profile_image_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastLoginDate: json['last_login_date'] != null
          ? DateTime.parse(json['last_login_date'] as String)
          : null,
      currentStreak: (json['current_streak'] as int?) ?? 0,
      loginDates: (json['login_dates'] as List<dynamic>?)
              ?.map((d) => DateTime.parse(d as String))
              .toList() ??
          const [],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'profile_image_path': profileImagePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_login_date': lastLoginDate?.toIso8601String(),
      'current_streak': currentStreak,
      'login_dates': loginDates.map((d) => d.toIso8601String()).toList(),
    };
  }

  /// Create a copy with updated fields
  UserProfileModel copyWith({
    String? name,
    String? profileImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginDate,
    int? currentStreak,
    List<DateTime>? loginDates,
  }) {
    return UserProfileModel(
      name: name ?? this.name,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      currentStreak: currentStreak ?? this.currentStreak,
      loginDates: loginDates ?? this.loginDates,
    );
  }

  @override
  String toString() =>
      'UserProfileModel(name: $name, hasImage: $hasProfilePicture, streak: $currentStreak, created: $createdAt)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfileModel &&
           other.name == name &&
           other.profileImagePath == profileImagePath;
  }

  @override
  int get hashCode =>
      name.hashCode ^
      profileImagePath.hashCode ^
      createdAt.hashCode;
}
