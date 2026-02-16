import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile_model.dart';
import '../repositories/user_profile_repository.dart';

/// Provider for user profile state management
/// Automatically loads profile on initialization
final userProfileProvider = AsyncNotifierProvider<UserProfileNotifier, UserProfileModel?>(
  UserProfileNotifier.new,
);

/// Notifier for managing user profile state
class UserProfileNotifier extends AsyncNotifier<UserProfileModel?> {
  late final UserProfileRepository _repository;

  @override
  Future<UserProfileModel?> build() async {
    _repository = UserProfileRepository();
    return await _loadProfile();
  }

  /// Load profile from repository
  Future<UserProfileModel?> _loadProfile() async {
    try {
      return await _repository.getProfile();
    } catch (e) {
      print('Error loading profile: $e');
      return null;
    }
  }

  /// Save or update profile
  Future<void> saveProfile(UserProfileModel profile) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.saveProfile(profile);
      return profile;
    });
  }

  /// Update profile with new data
  Future<void> updateProfile({
    String? name,
    String? profileImagePath,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateProfile(
        name: name,
        profileImagePath: profileImagePath,
      );
      return await _repository.getProfile();
    });
  }

  /// Record daily login and update streak.
  /// Returns the updated profile with new streak data.
  Future<UserProfileModel?> recordDailyLogin() async {
    final updatedProfile = await _repository.recordLogin();
    if (updatedProfile != null) {
      state = AsyncValue.data(updatedProfile);
    }
    return updatedProfile;
  }

  /// Delete profile
  Future<void> deleteProfile() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteProfile();
      return null;
    });
  }

  /// Reload profile from storage
  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _repository.getProfile();
    });
  }
}
