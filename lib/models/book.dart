import 'package:hive/hive.dart';

part 'book.g.dart';

@HiveType(typeId: 0)
class BookMetadata extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  List<String> author;

  @HiveField(2)
  String annotation;

  @HiveField(3)
  String filePath;

  @HiveField(4)
  int? lastPosition;

  @HiveField(5)
  DateTime addedDate;

  BookMetadata({
    required this.title,
    required this.author,
    required this.annotation,
    required this.filePath,
    this.lastPosition,
    required this.addedDate,
  });
}

class Book {
  final String title;
  final List<String> author;
  final String annotation;
  final String? coverImage;
  final List<BookSection> sections;
  final String content;
  final String? filePath;

  Book({
    required this.title,
    required this.author,
    required this.annotation,
    this.coverImage,
    required this.sections,
    required this.content,
    this.filePath
  });
}

class BookSection {
  final String title;
  final List<String> paragraphs;
  final List<BookSection> subsections;

  BookSection({
    required this.title,
    required this.paragraphs,
    required this.subsections
  });
}