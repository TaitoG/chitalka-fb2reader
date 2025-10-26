//bookmark.dart

import 'package:hive/hive.dart';

part 'bookmark.g.dart';

enum BookmarkType {
  word,
  sentence,
  paragraph,
}

@HiveType(typeId: 5)
class Bookmark extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String bookId;

  @HiveField(2)
  String bookTitle;

  @HiveField(3)
  BookmarkType type;

  @HiveField(4)
  String text;

  @HiveField(5)
  String? context;

  @HiveField(6)
  String? translation;

  @HiveField(7)
  int sectionIndex;
  @HiveField(8)
  int pageIndex;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime? lastReviewedAt;

  @HiveField(11)
  int reviewCount;

  @HiveField(12)
  String? notes;

  @HiveField(13)
  List<String> tags;

  @HiveField(14)
  bool isFavorite;

  Bookmark({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.type,
    required this.text,
    this.context,
    this.translation,
    required this.sectionIndex,
    required this.pageIndex,
    required this.createdAt,
    this.lastReviewedAt,
    this.reviewCount = 0,
    this.notes,
    this.tags = const [],
    this.isFavorite = false,
  });

  Bookmark copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    BookmarkType? type,
    String? text,
    String? context,
    String? translation,
    int? sectionIndex,
    int? pageIndex,
    DateTime? createdAt,
    DateTime? lastReviewedAt,
    int? reviewCount,
    String? notes,
    List<String>? tags,
    bool? isFavorite,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      type: type ?? this.type,
      text: text ?? this.text,
      context: context ?? this.context,
      translation: translation ?? this.translation,
      sectionIndex: sectionIndex ?? this.sectionIndex,
      pageIndex: pageIndex ?? this.pageIndex,
      createdAt: createdAt ?? this.createdAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      reviewCount: reviewCount ?? this.reviewCount,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  String toString() {
    return 'Bookmark(text: $text, type: $type, book: $bookTitle)';
  }
}

class BookmarkTypeAdapter extends TypeAdapter<BookmarkType> {
  @override
  final int typeId = 6;

  @override
  BookmarkType read(BinaryReader reader) {
    return BookmarkType.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, BookmarkType obj) {
    writer.writeByte(obj.index);
  }
}