import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../shared/models/models.dart';
import '../../features/profile/data/models/user_profile_model.dart';
import 'adapters/module_adapter.dart';
import 'adapters/lesson_adapter.dart';
import 'adapters/topic_adapter.dart';
import 'adapters/progress_adapter.dart';
import 'adapters/chat_message_adapter.dart';
import 'adapters/bookmark_adapter.dart';
import 'adapters/user_profile_adapter.dart';

/// Central Hive database service
/// Handles initialization and box management
class HiveService {
  HiveService._();

  // Box names
  static const String topicsBoxName = 'topics_box';
  static const String lessonsBoxName = 'lessons_box';
  static const String progressBoxName = 'progress_box';
  static const String chatHistoryBoxName = 'chat_history_box';
  static const String bookmarksBoxName = 'bookmarks_box';
  static const String userProfileBoxName = 'user_profile_box';
  /// Box for scenario-based chat history stored as JSON strings.
  /// Key = scenario ID, Value = JSON-encoded List<ChatMessage>.
  static const String scenarioChatJsonBoxName = 'scenario_chat_json_box';

  // Box instances
  static Box<TopicModel>? _topicsBox;
  static Box<LessonModel>? _lessonsBox;
  static Box<ProgressModel>? _progressBox;
  static Box<ChatMessageModel>? _chatHistoryBox;
  static Box<BookmarkModel>? _bookmarksBox; // Stores BookmarkModel objects
  static Box<UserProfileModel>? _userProfileBox;
  static Box<String>? _scenarioChatJsonBox;

  /// Initialize Hive and open all boxes
  /// Phase 0: Added integrity check with recovery flow per box
  static Future<void> init() async {
    // Initialize Hive Flutter
    await Hive.initFlutter();

    // Register TypeAdapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ModuleAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LessonAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(TopicAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ProgressAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(UserProfileAdapter());
    }

    // Open all boxes with integrity recovery
    _topicsBox = await _openBoxSafely<TopicModel>(topicsBoxName);
    _lessonsBox = await _openBoxSafely<LessonModel>(lessonsBoxName);
    _progressBox = await _openBoxSafely<ProgressModel>(progressBoxName);
    _chatHistoryBox = await _openBoxSafely<ChatMessageModel>(chatHistoryBoxName);
    _bookmarksBox = await _openBoxSafely<BookmarkModel>(bookmarksBoxName);
    _userProfileBox = await _openBoxSafely<UserProfileModel>(userProfileBoxName);
    _scenarioChatJsonBox = await _openBoxSafely<String>(scenarioChatJsonBoxName);
  }

  /// Open a Hive box safely with corruption recovery.
  /// If opening fails (corrupted data), deletes the box from disk and
  /// re-opens it empty. Data loss is preferable to app crash.
  static Future<Box<T>> _openBoxSafely<T>(String boxName) async {
    try {
      return await Hive.openBox<T>(boxName);
    } catch (e) {
      print('⚠️ Hive box "$boxName" corrupted: $e');
      print('🔄 Recovering by deleting and re-creating box...');
      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (_) {
        // Deletion may also fail if file is locked; ignore and try opening
      }
      return await Hive.openBox<T>(boxName);
    }
  }

  /// Get Topics Box
  static Box<TopicModel> get topicsBox {
    if (_topicsBox == null || !_topicsBox!.isOpen) {
      throw Exception('Topics box not initialized. Call HiveService.init() first.');
    }
    return _topicsBox!;
  }

  /// Get Lessons Box
  static Box<LessonModel> get lessonsBox {
    if (_lessonsBox == null || !_lessonsBox!.isOpen) {
      throw Exception('Lessons box not initialized. Call HiveService.init() first.');
    }
    return _lessonsBox!;
  }

  /// Get Progress Box
  static Box<ProgressModel> get progressBox {
    if (_progressBox == null || !_progressBox!.isOpen) {
      throw Exception('Progress box not initialized. Call HiveService.init() first.');
    }
    return _progressBox!;
  }

  /// Get Chat History Box
  static Box<ChatMessageModel> get chatHistoryBox {
    if (_chatHistoryBox == null || !_chatHistoryBox!.isOpen) {
      throw Exception('Chat history box not initialized. Call HiveService.init() first.');
    }
    return _chatHistoryBox!;
  }

  /// Alias for chatHistoryBox (for consistency)
  static Box<ChatMessageModel> get chatBox => chatHistoryBox;

  /// Get Scenario Chat JSON Box (key = scenario ID, value = JSON string).
  static Box<String> get scenarioChatJsonBox {
    if (_scenarioChatJsonBox == null || !_scenarioChatJsonBox!.isOpen) {
      throw Exception('Scenario chat JSON box not initialized. Call HiveService.init() first.');
    }
    return _scenarioChatJsonBox!;
  }

  /// Get Bookmarks Box
  static Box<BookmarkModel> get bookmarksBox {
    if (_bookmarksBox == null || !_bookmarksBox!.isOpen) {
      throw Exception('Bookmarks box not initialized. Call HiveService.init() first.');
    }
    return _bookmarksBox!;
  }

  /// Get User Profile Box
  static Box<UserProfileModel> get userProfileBox {
    if (_userProfileBox == null || !_userProfileBox!.isOpen) {
      throw Exception('User profile box not initialized. Call HiveService.init() first.');
    }
    return _userProfileBox!;
  }

  /// Close all boxes (call on app termination)
  static Future<void> closeAll() async {
    await _topicsBox?.close();
    await _lessonsBox?.close();
    await _progressBox?.close();
    await _chatHistoryBox?.close();
    await _bookmarksBox?.close();
    await _userProfileBox?.close();
    await _scenarioChatJsonBox?.close();
  }

  /// Clear all data (useful for testing/debugging)
  static Future<void> clearAll() async {
    await _topicsBox?.clear();
    await _lessonsBox?.clear();
    await _progressBox?.clear();
    await _chatHistoryBox?.clear();
    await _bookmarksBox?.clear();
    await _userProfileBox?.clear();
    await _scenarioChatJsonBox?.clear();
  }

  /// Delete all Hive data (nuclear option)
  static Future<void> deleteAll() async {
    await closeAll();
    await Hive.deleteBoxFromDisk(topicsBoxName);
    await Hive.deleteBoxFromDisk(lessonsBoxName);
    await Hive.deleteBoxFromDisk(progressBoxName);
    await Hive.deleteBoxFromDisk(chatHistoryBoxName);
    await Hive.deleteBoxFromDisk(bookmarksBoxName);
    await Hive.deleteBoxFromDisk(userProfileBoxName);
    await Hive.deleteBoxFromDisk(scenarioChatJsonBoxName);
  }
}