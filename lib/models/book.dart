
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