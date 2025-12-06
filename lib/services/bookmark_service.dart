// services/bookmark_service.dart
import 'package:hive/hive.dart';
import 'package:chitalka/models/bookmark.dart';
import 'package:uuid/uuid.dart';

class BookmarkService {
  Box<Bookmark>? _bookmarkBox;
  final _uuid = const Uuid();

  static const List<int> _intervals = [0, 1, 3, 7, 14, 30, 60];

  Future<void> initialize() async {
    if (_bookmarkBox != null) return;
    _bookmarkBox = await Hive.openBox<Bookmark>('bookmarks');
    print('📚 BookmarkService initialized: ${_bookmarkBox!.length} bookmarks');
  }

  Future<Bookmark> createBookmark({
    required String bookId,
    required String bookTitle,
    required BookmarkType type,
    required String text,
    String? context,
    String? translation,
    required int sectionIndex,
    required int pageIndex,
    String? notes,
    List<String> tags = const [],
  }) async {
    await initialize();

    final bookmark = Bookmark(
      id: _uuid.v4(),
      bookId: bookId,
      bookTitle: bookTitle,
      type: type,
      text: text,
      context: context,
      translation: translation,
      sectionIndex: sectionIndex,
      pageIndex: pageIndex,
      createdAt: DateTime.now(),
      notes: notes,
      tags: tags,
      currentRepetition: 0,
      totalCorrectCount: 0,
      nextReviewDate: null,
      intervalDays: 0,
      masteryLevel: 0,
      progressPercent: 0.0,
    );

    await _bookmarkBox!.put(bookmark.id, bookmark);
    print('✅ Bookmark created: ${bookmark.text}');
    return bookmark;
  }

  Future<List<Bookmark>> getAllBookmarks() async {
    await initialize();
    return _bookmarkBox!.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<Bookmark>> getBookmarksByBook(String bookId) async {
    await initialize();
    return _bookmarkBox!.values
        .where((b) => b.bookId == bookId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<Bookmark>> getBookmarksByType(BookmarkType type) async {
    await initialize();
    return _bookmarkBox!.values
        .where((b) => b.type == type)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<Bookmark>> getFavoriteBookmarks() async {
    await initialize();
    return _bookmarkBox!.values
        .where((b) => b.isFavorite)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<Bookmark>> searchBookmarks(String query) async {
    await initialize();
    final lowerQuery = query.toLowerCase();
    return _bookmarkBox!.values
        .where((b) =>
    b.text.toLowerCase().contains(lowerQuery) ||
        (b.translation?.toLowerCase().contains(lowerQuery) ?? false) ||
        (b.notes?.toLowerCase().contains(lowerQuery) ?? false))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<Bookmark>> getBookmarksByTag(String tag) async {
    await initialize();
    return _bookmarkBox!.values
        .where((b) => b.tags.contains(tag))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<bool> hasBookmark(String bookId, String text) async {
    await initialize();
    return _bookmarkBox!.values.any(
          (b) => b.bookId == bookId && b.text.toLowerCase() == text.toLowerCase(),
    );
  }

  Future<Bookmark?> findBookmark(String bookId, String text) async {
    await initialize();
    try {
      return _bookmarkBox!.values.firstWhere(
            (b) => b.bookId == bookId && b.text.toLowerCase() == text.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> updateBookmark(Bookmark bookmark) async {
    await initialize();
    await bookmark.save();
    print('✅ Bookmark updated: ${bookmark.text}');
  }

  Future<void> toggleFavorite(String bookmarkId) async {
    await initialize();
    final bookmark = _bookmarkBox!.get(bookmarkId);
    if (bookmark != null) {
      bookmark.isFavorite = !bookmark.isFavorite;
      await bookmark.save();
      print('⭐ Bookmark favorite toggled: ${bookmark.text}');
    }
  }

  Future<void> addTag(String bookmarkId, String tag) async {
    await initialize();
    final bookmark = _bookmarkBox!.get(bookmarkId);
    if (bookmark != null && !bookmark.tags.contains(tag)) {
      bookmark.tags.add(tag);
      await bookmark.save();
      print('🏷️ Tag added: $tag to ${bookmark.text}');
    }
  }

  Future<void> removeTag(String bookmarkId, String tag) async {
    await initialize();
    final bookmark = _bookmarkBox!.get(bookmarkId);
    if (bookmark != null) {
      bookmark.tags.remove(tag);
      await bookmark.save();
      print('🏷️ Tag removed: $tag from ${bookmark.text}');
    }
  }

  Future<void> markAsReviewed(String bookmarkId) async {
    await markAsCorrect(bookmarkId);
  }

  Future<void> deleteBookmark(String bookmarkId) async {
    await initialize();
    await _bookmarkBox!.delete(bookmarkId);
    print('🗑️ Bookmark deleted');
  }

  Future<void> deleteBookmarksByBook(String bookId) async {
    await initialize();
    final toDelete = _bookmarkBox!.values
        .where((b) => b.bookId == bookId)
        .map((b) => b.id)
        .toList();

    for (final id in toDelete) {
      await _bookmarkBox!.delete(id);
    }
    print('🗑️ Deleted ${toDelete.length} bookmarks for book $bookId');
  }

  Future<List<String>> getAllTags() async {
    await initialize();
    final tags = <String>{};
    for (final bookmark in _bookmarkBox!.values) {
      tags.addAll(bookmark.tags);
    }
    return tags.toList()..sort();
  }

  // ============ SRS METHODS ============

  Future<List<Bookmark>> getCardsForToday() async {
    await initialize();
    final allWords = _bookmarkBox!.values.where((b) => b.type == BookmarkType.word).toList();

    final cardsForToday = allWords.where((word) => word.needsReviewToday()).toList();

    return cardsForToday;
  }

  Future<void> markAsCorrect(String bookmarkId) async {
    await initialize();
    final bookmark = _bookmarkBox!.get(bookmarkId);
    if (bookmark == null) return;

    final now = DateTime.now();
    bookmark.lastReviewedAt = now;
    bookmark.reviewCount = bookmark.reviewCount + 1;
    bookmark.currentRepetition = bookmark.currentRepetition + 1;
    bookmark.totalCorrectCount = bookmark.totalCorrectCount + 1;

    bookmark.progressPercent = (bookmark.progressPercent + 10).clamp(0, 100);

    if (bookmark.currentRepetition >= 3) {
      await _advanceToNextLevel(bookmark);
    } else {
      await bookmark.save();
    }

    print('✅ Marked as correct: ${bookmark.text} (${bookmark.currentRepetition}/3, progress: ${bookmark.progressPercent.toStringAsFixed(0)}%)');
  }

  Future<void> markAsIncorrect(String bookmarkId) async {
    await initialize();
    final bookmark = _bookmarkBox!.get(bookmarkId);
    if (bookmark == null) return;

    final now = DateTime.now();
    bookmark.lastReviewedAt = now;
    bookmark.reviewCount = bookmark.reviewCount + 1;
    bookmark.currentRepetition = 0;

    bookmark.progressPercent = (bookmark.progressPercent - 15).clamp(0, 100);

    if (bookmark.masteryLevel > 0) {
      bookmark.masteryLevel = bookmark.masteryLevel - 1;
      bookmark.intervalDays = _intervals[bookmark.masteryLevel];
    }

    bookmark.nextReviewDate = now;

    await bookmark.save();
    print('❌ Marked as incorrect: ${bookmark.text} (progress: ${bookmark.progressPercent.toStringAsFixed(0)}%)');
  }

  Future<void> _advanceToNextLevel(Bookmark bookmark) async {
    final newMasteryLevel = bookmark.masteryLevel < _intervals.length - 1
        ? bookmark.masteryLevel + 1
        : bookmark.masteryLevel;

    final intervalDays = _intervals[newMasteryLevel];
    final nextReview = DateTime.now().add(Duration(days: intervalDays));

    bookmark.masteryLevel = newMasteryLevel;
    bookmark.intervalDays = intervalDays;
    bookmark.nextReviewDate = nextReview;
    bookmark.currentRepetition = 0;

    bookmark.progressPercent = (bookmark.progressPercent + 5).clamp(0, 100);

    await bookmark.save();
    print('🎉 Advanced to level $newMasteryLevel: ${bookmark.text} (next: ${intervalDays}d, progress: ${bookmark.progressPercent.toStringAsFixed(0)}%)');
  }

  Future<void> resetSessionProgress(String bookmarkId) async {
    await initialize();
    final bookmark = _bookmarkBox!.get(bookmarkId);
    if (bookmark == null) return;

    bookmark.currentRepetition = 0;
    await bookmark.save();
    print('🔄 Session progress reset: ${bookmark.text}');
  }

  Future<Map<String, dynamic>> getStatistics() async {
    await initialize();
    final bookmarks = _bookmarkBox!.values.toList();
    final allWords = bookmarks.where((b) => b.type == BookmarkType.word).toList();

    final dueToday = allWords.where((w) => w.needsReviewToday()).length;
    final newWords = allWords.where((w) => w.masteryLevel == 0).length;
    final learning = allWords.where((w) => w.masteryLevel > 0 && w.masteryLevel < 3).length;
    final mastered = allWords.where((w) => w.masteryLevel >= 5).length;

    return {
      'total': bookmarks.length,
      'words': allWords.length,
      'sentences': bookmarks.where((b) => b.type == BookmarkType.sentence).length,
      'paragraphs': bookmarks.where((b) => b.type == BookmarkType.paragraph).length,
      'favorites': bookmarks.where((b) => b.isFavorite).length,
      'reviewed': bookmarks.where((b) => b.reviewCount > 0).length,
      'totalReviews': bookmarks.fold<int>(0, (sum, b) => sum + b.reviewCount),
      'dueToday': dueToday,
      'new': newWords,
      'learning': learning,
      'mastered': mastered,
    };
  }

  Future<List<Map<String, dynamic>>> exportBookmarks() async {
    await initialize();
    return _bookmarkBox!.values.map((b) {
      return {
        'id': b.id,
        'bookId': b.bookId,
        'bookTitle': b.bookTitle,
        'type': b.type.name,
        'text': b.text,
        'context': b.context,
        'translation': b.translation,
        'sectionIndex': b.sectionIndex,
        'pageIndex': b.pageIndex,
        'createdAt': b.createdAt.toIso8601String(),
        'lastReviewedAt': b.lastReviewedAt?.toIso8601String(),
        'reviewCount': b.reviewCount,
        'notes': b.notes,
        'tags': b.tags,
        'isFavorite': b.isFavorite,
        'currentRepetition': b.currentRepetition,
        'totalCorrectCount': b.totalCorrectCount,
        'nextReviewDate': b.nextReviewDate?.toIso8601String(),
        'intervalDays': b.intervalDays,
        'masteryLevel': b.masteryLevel,
        'progressPercent': b.progressPercent,
      };
    }).toList();
  }

  Future<void> dispose() async {
    await _bookmarkBox?.close();
  }
}