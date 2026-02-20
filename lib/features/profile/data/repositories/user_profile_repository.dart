import '../../../../services/storage/hive_service.dart';
import '../models/user_profile_model.dart';

/// Repository for managing user profile data in Hive
/// Stores a single profile with key 'current_profile'
class UserProfileRepository {
  static const String _profileKey = 'current_profile';

  /// Get the current user profile
  /// Returns null if no profile exists
  Future<UserProfileModel?> getProfile() async {
    try {
      final box = HiveService.userProfileBox;
      return box.get(_profileKey);
    } catch (e) {
      print('Error getting profile: $e');
      return null;
    }
  }

  /// Save or update the user profile
  /// If a profile already exists, it will be replaced
  Future<void> saveProfile(UserProfileModel profile) async {
    try {
      final box = HiveService.userProfileBox;
      await box.put(_profileKey, profile);
    } catch (e) {
      print('Error saving profile: $e');
      rethrow;
    }
  }

  /// Delete the current user profile
  Future<void> deleteProfile() async {
    try {
      final box = HiveService.userProfileBox;
      await box.delete(_profileKey);
    } catch (e) {
      print('Error deleting profile: $e');
      rethrow;
    }
  }

  /// Check if a profile exists
  Future<bool> hasProfile() async {
    try {
      final box = HiveService.userProfileBox;
      return box.containsKey(_profileKey);
    } catch (e) {
      print('Error checking profile existence: $e');
      return false;
    }
  }

  /// Update profile with new data
  /// Preserves createdAt timestamp, updates updatedAt
  Future<void> updateProfile({
    String? name,
    String? profileImagePath,
    String? fullName,
    String? gradeSection,
    String? school,
  }) async {
    try {
      final currentProfile = await getProfile();
      if (currentProfile == null) {
        throw Exception('No profile to update. Create a profile first.');
      }

      final updatedProfile = currentProfile.copyWith(
        name: name,
        profileImagePath: profileImagePath,
        fullName: fullName,
        gradeSection: gradeSection,
        school: school,
        updatedAt: DateTime.now(),
      );

      await saveProfile(updatedProfile);
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  /// Record a daily login and update streak data.
  /// Returns the updated profile with new streak info.
  /// If already logged in today, returns current profile unchanged.
  Future<UserProfileModel?> recordLogin() async {
    try {
      final profile = await getProfile();
      if (profile == null) return null;

      final now = DateTime.now();

      // Already logged in today - no change needed
      if (profile.lastLoginDate != null &&
          _isSameDay(profile.lastLoginDate!, now)) {
        return profile;
      }

      // Add today to login dates and prune to last 30 days
      final updatedDates = [...profile.loginDates, now];
      // Remove dates older than 30 days
      final cutoff = now.subtract(const Duration(days: 30));
      updatedDates.removeWhere((d) => d.isBefore(cutoff));

      // Calculate new streak
      final newStreak = _calculateStreak(updatedDates, now);

      final updatedProfile = profile.copyWith(
        lastLoginDate: now,
        currentStreak: newStreak,
        loginDates: updatedDates,
        updatedAt: now,
      );

      await saveProfile(updatedProfile);
      return updatedProfile;
    } catch (e) {
      print('Error recording login: $e');
      return null;
    }
  }

  /// Calculate consecutive day streak from login dates.
  /// Counts backward from today checking each previous day.
  int _calculateStreak(List<DateTime> dates, DateTime today) {
    if (dates.isEmpty) return 0;

    // Normalize dates to date-only (remove time component) and deduplicate
    final uniqueDays = <String>{};
    for (final d in dates) {
      uniqueDays.add('${d.year}-${d.month}-${d.day}');
    }

    int streak = 0;
    // Check today and consecutive previous days
    for (int i = 0; i < 365; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final key = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
      if (uniqueDays.contains(key)) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  /// Check if two DateTimes represent the same calendar day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Get login status for the last 7 days (today = index 6, 6 days ago = index 0).
  /// Returns a list of 7 booleans.
  List<bool> getLast7Days(List<DateTime> loginDates) {
    final today = DateTime.now();
    final uniqueDays = <String>{};
    for (final d in loginDates) {
      uniqueDays.add('${d.year}-${d.month}-${d.day}');
    }

    return List.generate(7, (index) {
      // index 0 = 6 days ago, index 6 = today
      final checkDate = today.subtract(Duration(days: 6 - index));
      final key = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
      return uniqueDays.contains(key);
    });
  }

  /// Get login status for the current week (Monday through Sunday).
  /// Returns a list of 7 booleans: index 0 = Monday, index 6 = Sunday.
  /// Future days in the week always return false.
  List<bool> getCurrentWeekStatus(List<DateTime> loginDates) {
    final today = DateTime.now();
    // Calculate Monday of the current week (weekday: 1=Mon, 7=Sun)
    final monday = today.subtract(Duration(days: today.weekday - 1));

    final uniqueDays = <String>{};
    for (final d in loginDates) {
      uniqueDays.add('${d.year}-${d.month}-${d.day}');
    }

    return List.generate(7, (index) {
      // index 0 = Monday, index 6 = Sunday
      final checkDate = DateTime(monday.year, monday.month, monday.day + index);
      // Future days return false
      if (checkDate.isAfter(today)) return false;
      final key = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
      return uniqueDays.contains(key);
    });
  }
}
