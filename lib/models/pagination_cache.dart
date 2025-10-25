//pagination_cache.dart

import 'package:hive/hive.dart';

part 'pagination_cache.g.dart';

@HiveType(typeId: 1)
class PaginationCache extends HiveObject {
  @HiveField(0)
  String bookFilePath;

  @HiveField(1)
  double fontSize;

  @HiveField(2)
  double lineHeight;

  @HiveField(3)
  double screenWidth;

  @HiveField(4)
  double screenHeight;

  @HiveField(5)
  Map<int, SectionPaginationData> sections;

  @HiveField(6)
  DateTime createdAt;

  PaginationCache({
    required this.bookFilePath,
    required this.fontSize,
    required this.lineHeight,
    required this.screenWidth,
    required this.screenHeight,
    required this.sections,
    required this.createdAt,
  });

  bool isValid(double currentFontSize, double currentLineHeight,
      double currentWidth, double currentHeight) {
    return fontSize == currentFontSize &&
        lineHeight == currentLineHeight &&
        (screenWidth - currentWidth).abs() < 1 &&
        (screenHeight - currentHeight).abs() < 1;
  }
}

@HiveType(typeId: 2)
class SectionPaginationData {
  @HiveField(0)
  int sectionIndex;

  @HiveField(1)
  List<PageTokenData> pages;

  SectionPaginationData({
    required this.sectionIndex,
    required this.pages,
  });
}

@HiveType(typeId: 3)
class PageTokenData {
  @HiveField(0)
  String text;

  @HiveField(1)
  List<TokenData> tokens;

  PageTokenData({
    required this.text,
    required this.tokens,
  });
}

@HiveType(typeId: 4)
class TokenData {
  @HiveField(0)
  String text;

  @HiveField(1)
  String word;

  @HiveField(2)
  int startOffset;

  TokenData({
    required this.text,
    required this.word,
    required this.startOffset,
  });
}