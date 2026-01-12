import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences Service for persistent app settings
class SharedPrefsService {
  SharedPrefsService._();

  static SharedPreferences? _prefs;

  // KEYS
  static const String _keyFirstLaunch = 'is_first_launch';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyDataSeeded = 'data_seeded'; // NEW: for data seeding

  /// Initialize SharedPreferences
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Check if this is the first launch
  static bool get isFirstLaunch {
    return _prefs?.getBool(_keyFirstLaunch) ?? true;
  }

  /// Mark that the app has been launched
  static Future<void> setFirstLaunchComplete() async {
    await _prefs?.setBool(_keyFirstLaunch, false);
  }

  /// Check if onboarding is completed
  static bool get isOnboardingCompleted {
    return _prefs?.getBool(_keyOnboardingCompleted) ?? false;
  }

  /// Mark onboarding as completed
  static Future<void> setOnboardingCompleted() async {
    await _prefs?.setBool(_keyOnboardingCompleted, true);
  }

  /// Reset to first launch (useful for testing)
  static Future<void> resetFirstLaunch() async {
    await _prefs?.setBool(_keyFirstLaunch, true);
    await _prefs?.setBool(_keyOnboardingCompleted, false);
  }

  // NEW: Data Seeding Methods
  
  /// Check if data has been seeded
  static bool get isDataSeeded {
    return _prefs?.getBool(_keyDataSeeded) ?? false;
  }

  /// Mark data as seeded
  static Future<void> setDataSeeded() async {
    await _prefs?.setBool(_keyDataSeeded, true);
  }

  /// Reset data seeded flag (useful for testing)
  static Future<void> resetDataSeeded() async {
    await _prefs?.setBool(_keyDataSeeded, false);
  }

  /// Clear all preferences (useful for testing)
  static Future<void> clearAll() async {
    await _prefs?.clear();
  }
}