// services/pagination.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:chitalka/models/book.dart';
import 'package:chitalka/models/pagination_cache.dart';
import 'package:chitalka/models/page_data.dart';
import 'package:chitalka/models/word_token.dart';
import 'package:chitalka/core/tokenizer.dart';

class PaginationService {
  Box<PaginationCache>? _cacheBox;
  PaginationCache? _currentCache;
  final Map<int, List<PageData>> _sectionPages = {};
  final Set<int> _paginatedSections = {};
  bool _isBackgroundPaginationRunning = false;

  VoidCallback? onPaginationUpdate;
  VoidCallback? onBackgroundPaginationComplete;

  bool get isBackgroundPaginationRunning => _isBackgroundPaginationRunning;
  Map<int, List<PageData>> get sectionPages => _sectionPages;
  PaginationCache? get currentCache => _currentCache;

  Future<void> initializeCache() async {
    _cacheBox = await Hive.openBox<PaginationCache>('pagination_cache');
  }

  Future<void> loadOrCreatePagination({
    required Book book,
    required String? cacheKey,
    required double fontSize,
    required double lineHeight,
    required Size screenSize,
    required int currentSectionIndex,
  }) async {
    if (cacheKey == null) return;

    _currentCache = _cacheBox?.get(cacheKey);

    if (_currentCache != null &&
        _currentCache!.isValid(fontSize, lineHeight, screenSize.width, screenSize.height)) {
      await loadSectionFromCache(currentSectionIndex);
      preloadNearbySections(currentSectionIndex, book.sections.length);
    } else {
      _currentCache = PaginationCache(
        bookFilePath: cacheKey,
        fontSize: fontSize,
        lineHeight: lineHeight,
        screenWidth: screenSize.width,
        screenHeight: screenSize.height,
        sections: {},
        createdAt: DateTime.now(),
      );

      await paginateSection(
        book: book,
        sectionIndex: currentSectionIndex,
        fontSize: fontSize,
        lineHeight: lineHeight,
        screenSize: screenSize,
      );

      startBackgroundPagination(
        book: book,
        fontSize: fontSize,
        lineHeight: lineHeight,
        screenSize: screenSize,
      );
    }
  }
  Future<void> loadSectionFromCache(int sectionIndex) async {
    if (_currentCache?.sections.containsKey(sectionIndex) ?? false) {
      final cachedSection = _currentCache!.sections[sectionIndex]!;
      _sectionPages[sectionIndex] = cachedSection.pages.map((pageData) {
        return PageData(
          text: pageData.text,
          tokens: pageData.tokens.map((tokenData) {
            return WordToken(
              text: tokenData.text,
              word: tokenData.word,
              startOffset: tokenData.startOffset,
            );
          }).toList(),
        );
      }).toList();

      _paginatedSections.add(sectionIndex);
      onPaginationUpdate?.call();
    }
  }

  void preloadNearbySections(int currentSectionIndex, int totalSections) {
    final sectionsToLoad = <int>[];

    if (currentSectionIndex > 0) {
      sectionsToLoad.add(currentSectionIndex - 1);
    }
    if (currentSectionIndex < totalSections - 1) {
      sectionsToLoad.add(currentSectionIndex + 1);
    }

    for (final sectionIndex in sectionsToLoad) {
      if (!_paginatedSections.contains(sectionIndex)) {
        loadSectionFromCache(sectionIndex);
      }
    }
  }

  void startBackgroundPagination({
    required Book book,
    required double fontSize,
    required double lineHeight,
    required Size screenSize,
  }) {
    if (_isBackgroundPaginationRunning) return;
    _isBackgroundPaginationRunning = true;

    Future.delayed(const Duration(milliseconds: 500), () {
      _paginateNextSection(
        book: book,
        fontSize: fontSize,
        lineHeight: lineHeight,
        screenSize: screenSize,
      );
    });
  }

  Future<void> _paginateNextSection({
    required Book book,
    required double fontSize,
    required double lineHeight,
    required Size screenSize,
  }) async {
    if (!_isBackgroundPaginationRunning) return;

    int? nextSection;
    for (int i = 0; i < book.sections.length; i++) {
      if (!_paginatedSections.contains(i)) {
        nextSection = i;
        break;
      }
    }

    if (nextSection != null) {
      await paginateSection(
        book: book,
        sectionIndex: nextSection,
        fontSize: fontSize,
        lineHeight: lineHeight,
        screenSize: screenSize,
        background: true,
      );

      Future.delayed(const Duration(milliseconds: 100), () {
        _paginateNextSection(
          book: book,
          fontSize: fontSize,
          lineHeight: lineHeight,
          screenSize: screenSize,
        );
      });
    } else {
      _isBackgroundPaginationRunning = false;
      await saveCacheToHive();
      onBackgroundPaginationComplete?.call();
    }
  }

  Future<void> paginateSection({
    required Book book,
    required int sectionIndex,
    required double fontSize,
    required double lineHeight,
    required Size screenSize,
    EdgeInsets? mediaPadding,
    bool background = false,
  }) async {
    if (_paginatedSections.contains(sectionIndex)) return;

    final section = book.sections[sectionIndex];
    final paragraphs = section.paragraphs;
    final padding = const EdgeInsets.all(24.0);

    final effectiveMediaPadding = mediaPadding ?? EdgeInsets.zero;
    final availableHeight = screenSize.height -
        effectiveMediaPadding.vertical -
        padding.vertical -
        32;

    final textStyle = TextStyle(fontSize: fontSize, height: lineHeight);
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    List<PageData> pages = [];
    StringBuffer currentPageText = StringBuffer();
    List<WordToken> currentPageTokens = [];

    for (final paragraph in paragraphs) {
      final paragraphTokens = TextTokenizer.tokenize(paragraph + '\n\u00A0\u00A0\u00A0');
      final paragraphText = paragraphTokens.map((t) => t.text).join();

      final tentativeText = currentPageText.toString() + paragraphText;
      textPainter.text = TextSpan(text: tentativeText, style: textStyle);
      textPainter.layout(maxWidth: screenSize.width - padding.horizontal);

      if (textPainter.height <= availableHeight) {
        currentPageText.write(paragraphText);
        currentPageTokens.addAll(paragraphTokens);
        continue;
      }

      int tokenIndex = 0;
      while (tokenIndex < paragraphTokens.length) {
        final token = paragraphTokens[tokenIndex];

        StringBuffer testText = StringBuffer(currentPageText.toString());
        testText.write(token.text);

        textPainter.text = TextSpan(text: testText.toString(), style: textStyle);
        textPainter.layout(maxWidth: screenSize.width - padding.horizontal);

        if (textPainter.height <= availableHeight) {
          currentPageText.write(token.text);
          currentPageTokens.add(token);
          tokenIndex++;
        } else {
          if (currentPageText.isNotEmpty) {
            pages.add(PageData(
              text: currentPageText.toString().trim(),
              tokens: List.from(currentPageTokens),
            ));
          }

          currentPageText = StringBuffer(token.text);
          currentPageTokens = [token];
          tokenIndex++;

          textPainter.text = TextSpan(text: token.text, style: textStyle);
          textPainter.layout(maxWidth: screenSize.width - padding.horizontal);

          if (textPainter.height > availableHeight) {
            pages.add(PageData(
              text: currentPageText.toString(),
              tokens: List.from(currentPageTokens),
            ));
            currentPageText.clear();
            currentPageTokens.clear();
          }
        }
      }
    }

    if (currentPageText.isNotEmpty) {
      pages.add(PageData(
        text: currentPageText.toString().trim(),
        tokens: List.from(currentPageTokens),
      ));
    }

    _sectionPages[sectionIndex] = pages;
    _paginatedSections.add(sectionIndex);

    if (_currentCache != null) {
      _currentCache!.sections[sectionIndex] = SectionPaginationData(
        sectionIndex: sectionIndex,
        pages: pages.map((page) => PageTokenData(
          text: page.text,
          tokens: page.tokens.map((token) => TokenData(
            text: token.text,
            word: token.word,
            startOffset: token.startOffset,
          )).toList(),
        )).toList(),
      );
    }

    if (!background) {
      onPaginationUpdate?.call();
    }
  }

  bool isSectionLoaded(int sectionIndex) {
    return _paginatedSections.contains(sectionIndex);
  }

  List<PageData> getSectionPages(int sectionIndex) {
    return _sectionPages[sectionIndex] ?? [PageData(text: '', tokens: [])];
  }

  Future<void> saveCacheToHive() async {
    if (_currentCache == null) return;
    final cacheKey = _currentCache!.bookFilePath;
    await _cacheBox?.put(cacheKey, _currentCache!);
  }

  void clear() {
    _sectionPages.clear();
    _paginatedSections.clear();
    _currentCache = null;
    _isBackgroundPaginationRunning = false;
  }

  Future<void> dispose() async {
    await saveCacheToHive();
    _isBackgroundPaginationRunning = false;
  }
}