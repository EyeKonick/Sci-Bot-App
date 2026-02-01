import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../shared/models/models.dart';
import 'adapters/module_adapter.dart';
import 'adapters/lesson_adapter.dart';
import 'adapters/topic_adapter.dart';
import 'adapters/progress_adapter.dart';
import 'adapters/chat_message_adapter.dart';
import 'adapters/bookmark_adapter.dart';

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

  // Box instances
  static Box<TopicModel>? _topicsBox;
  static Box<LessonModel>? _lessonsBox;
  static Box<ProgressModel>? _progressBox;
  static Box<ChatMessageModel>? _chatHistoryBox;
  static Box<BookmarkModel>? _bookmarksBox; // Stores BookmarkModel objects

  /// Initialize Hive and open all boxes
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

    // Open all boxes
    _topicsBox = await Hive.openBox<TopicModel>(topicsBoxName);
    _lessonsBox = await Hive.openBox<LessonModel>(lessonsBoxName);
    _progressBox = await Hive.openBox<ProgressModel>(progressBoxName);
    _chatHistoryBox = await Hive.openBox<ChatMessageModel>(chatHistoryBoxName);
    _bookmarksBox = await Hive.openBox<BookmarkModel>(bookmarksBoxName);
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

  /// Get Bookmarks Box
  static Box<BookmarkModel> get bookmarksBox {
    if (_bookmarksBox == null || !_bookmarksBox!.isOpen) {
      throw Exception('Bookmarks box not initialized. Call HiveService.init() first.');
    }
    return _bookmarksBox!;
  }

  /// Close all boxes (call on app termination)
  static Future<void> closeAll() async {
    await _topicsBox?.close();
    await _lessonsBox?.close();
    await _progressBox?.close();
    await _chatHistoryBox?.close();
    await _bookmarksBox?.close();
  }

  /// Clear all data (useful for testing/debugging)
  static Future<void> clearAll() async {
    await _topicsBox?.clear();
    await _lessonsBox?.clear();
    await _progressBox?.clear();
    await _chatHistoryBox?.clear();
    await _bookmarksBox?.clear();
  }

  /// Delete all Hive data (nuclear option)
  static Future<void> deleteAll() async {
    await closeAll();
    await Hive.deleteBoxFromDisk(topicsBoxName);
    await Hive.deleteBoxFromDisk(lessonsBoxName);
    await Hive.deleteBoxFromDisk(progressBoxName);
    await Hive.deleteBoxFromDisk(chatHistoryBoxName);
    await Hive.deleteBoxFromDisk(bookmarksBoxName);
  }
}