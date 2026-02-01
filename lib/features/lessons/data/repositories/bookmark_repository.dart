import '../../../../shared/models/models.dart';
import '../../../../services/storage/hive_service.dart';

/// Repository for managing lesson bookmarks
class BookmarkRepository {
  /// Check if a lesson is bookmarked
  bool isBookmarked(String lessonId) {
    return HiveService.bookmarksBox.containsKey(lessonId);
  }

  /// Get all bookmarked lessons
  List<BookmarkModel> getAllBookmarks() {
    return HiveService.bookmarksBox.values.toList()
      ..sort((a, b) => b.bookmarkedAt.compareTo(a.bookmarkedAt)); // Most recent first
  }

  /// Get bookmark for a specific lesson
  BookmarkModel? getBookmark(String lessonId) {
    return HiveService.bookmarksBox.get(lessonId);
  }

  /// Add a bookmark
  Future<void> addBookmark({
    required String lessonId,
    required String topicId,
    String? notes,
  }) async {
    final bookmark = BookmarkModel(
      lessonId: lessonId,
      topicId: topicId,
      bookmarkedAt: DateTime.now(),
      notes: notes,
    );
    
    await HiveService.bookmarksBox.put(lessonId, bookmark);
  }

  /// Remove a bookmark
  Future<void> removeBookmark(String lessonId) async {
    await HiveService.bookmarksBox.delete(lessonId);
  }

  /// Toggle bookmark (add if not bookmarked, remove if bookmarked)
  Future<bool> toggleBookmark({
    required String lessonId,
    required String topicId,
    String? notes,
  }) async {
    if (isBookmarked(lessonId)) {
      await removeBookmark(lessonId);
      return false; // Removed
    } else {
      await addBookmark(
        lessonId: lessonId,
        topicId: topicId,
        notes: notes,
      );
      return true; // Added
    }
  }

  /// Get count of bookmarks
  int getBookmarksCount() {
    return HiveService.bookmarksBox.length;
  }

  /// Get bookmarks for a specific topic
  List<BookmarkModel> getBookmarksByTopic(String topicId) {
    return HiveService.bookmarksBox.values
        .where((bookmark) => bookmark.topicId == topicId)
        .toList()
      ..sort((a, b) => b.bookmarkedAt.compareTo(a.bookmarkedAt));
  }

  /// Clear all bookmarks
  Future<void> clearAll() async {
    await HiveService.bookmarksBox.clear();
  }

  /// Update bookmark notes
  Future<void> updateNotes(String lessonId, String notes) async {
    final bookmark = getBookmark(lessonId);
    if (bookmark != null) {
      final updated = bookmark.copyWith(notes: notes);
      await HiveService.bookmarksBox.put(lessonId, updated);
    }
  }
}