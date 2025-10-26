// services/bookmark.dart

import 'package:hive/hive.dart';
import 'package:chitalka/models/bookmark.dart';
import 'package:uuid/uuid.dart';

class BookmarkService {
  Box<Bookmark>? _bookmarkBox;
  final _uuid = const Uuid();

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
    await initialize();
    final bookmark = _bookmarkBox!.get(bookmarkId);
    if (bookmark != null) {
      bookmark.reviewCount++;
      bookmark.lastReviewedAt = DateTime.now();
      await bookmark.save();
      print('📖 Bookmark reviewed: ${bookmark.text} (${bookmark.reviewCount} times)');
    }
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

  Future<Map<String, dynamic>> getStatistics() async {
    await initialize();
    final bookmarks = _bookmarkBox!.values.toList();

    return {
      'total': bookmarks.length,
      'words': bookmarks.where((b) => b.type == BookmarkType.word).length,
      'sentences': bookmarks.where((b) => b.type == BookmarkType.sentence).length,
      'paragraphs': bookmarks.where((b) => b.type == BookmarkType.paragraph).length,
      'favorites': bookmarks.where((b) => b.isFavorite).length,
      'reviewed': bookmarks.where((b) => b.reviewCount > 0).length,
      'totalReviews': bookmarks.fold<int>(0, (sum, b) => sum + b.reviewCount),
    };
  }

  Future<List<Map<String, dynamic>>> exportBookmarks() async {
    await initialize();
    return _bookmarkBox!.values.map((b) => {
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
    }).toList();
  }

  Future<void> dispose() async {
    await _bookmarkBox?.close();
  }
}