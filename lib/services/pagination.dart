// services/pagination_optimized.dart
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
  final Set<int> _paginatingNow = {};
  bool _isBackgroundPaginationRunning = false;

  final Set<int> _dirtySections = {};
  DateTime? _lastSaveTime;

  VoidCallback? onPaginationUpdate;
  VoidCallback? onBackgroundPaginationComplete;

  bool get isBackgroundPaginationRunning => _isBackgroundPaginationRunning;
  Map<int, List<PageData>> get sectionPages => _sectionPages;
  PaginationCache? get currentCache => _currentCache;

  Future<void> initializeCache() async {
    if (_cacheBox != null) {
      print('✅ Cache box already initialized');
      return;
    }

    print('📦 Opening pagination cache box...');
    try {
      _cacheBox = await Hive.openBox<PaginationCache>('pagination_cache');
      print('✅ Cache box opened successfully. Keys: ${_cacheBox?.keys.length}');
    } catch (e) {
      print('❌ Error opening cache box: $e');
    }
  }

  Future<void> loadOrCreatePagination({
    required Book book,
    required String? cacheKey,
    required double fontSize,
    required double lineHeight,
    required Size screenSize,
    required double textContainerHeight,
    required int currentSectionIndex,
  }) async {
    if (cacheKey == null) {
      print('❌ cacheKey is null!');
      return;
    }

    print('📖 Loading pagination for: $cacheKey');
    print('📦 Available cache keys: ${_cacheBox?.keys.toList()}');

    _currentCache = _cacheBox?.get(cacheKey);
    print('🔍 Cache lookup result: ${_currentCache != null ? "FOUND" : "NOT FOUND"}');

    if (_currentCache != null) {
      print('✅ Cache found! Checking validity...');

      final isValid = _isCacheValid(
        _currentCache!,
        fontSize,
        lineHeight,
        screenSize.width,
        screenSize.height,
      );

      if (isValid) {
        print('✅ Cache is valid! Loading sections...');
        print('📚 Cached sections: ${_currentCache!.sections.keys.toList()}');

        await loadSectionFromCache(currentSectionIndex);

        preloadNearbySections(currentSectionIndex, book.sections.length);

        print('✅ Loaded ${_paginatedSections.length} sections from cache');

        if (_paginatedSections.length < book.sections.length) {
          print('🔄 Starting background pagination for remaining sections...');
          startBackgroundPagination(
            book: book,
            fontSize: fontSize,
            lineHeight: lineHeight,
            screenSize: screenSize,
            textContainerHeight: textContainerHeight,
            startFrom: currentSectionIndex,
          );
        } else {
          print('✅ All sections already cached!');
        }

        return;
      } else {
        print('❌ Cache invalid (screen size or font changed), recreating...');
      }
    } else {
      print('❌ No cache found, creating new...');
    }

    _currentCache = PaginationCache(
      bookFilePath: cacheKey,
      fontSize: fontSize,
      lineHeight: lineHeight,
      screenWidth: screenSize.width,
      screenHeight: screenSize.height,
      sections: {},
      createdAt: DateTime.now(),
    );

    print('⚡ Paginating current section only...');

    await _paginateSectionFast(
      book: book,
      sectionIndex: currentSectionIndex,
      fontSize: fontSize,
      lineHeight: lineHeight,
      screenSize: screenSize,
      textContainerHeight: textContainerHeight,
    );

    print('✅ Current section ready, starting background pagination...');

    startBackgroundPagination(
      book: book,
      fontSize: fontSize,
      lineHeight: lineHeight,
      screenSize: screenSize,
      textContainerHeight: textContainerHeight,
      startFrom: currentSectionIndex,
    );
  }

  bool _isCacheValid(
      PaginationCache cache,
      double fontSize,
      double lineHeight,
      double screenWidth,
      double screenHeight,
      ) {
    const tolerance = 5.0;

    final fontMatch = (cache.fontSize - fontSize).abs() < 0.1;
    final lineHeightMatch = (cache.lineHeight - lineHeight).abs() < 0.01;
    final widthMatch = (cache.screenWidth - screenWidth).abs() < tolerance;
    final heightMatch = (cache.screenHeight - screenHeight).abs() < tolerance;

    return fontMatch && lineHeightMatch && widthMatch && heightMatch;
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
    }
  }

  void preloadNearbySections(int currentSectionIndex, int totalSections) {
    final sectionsToLoad = <int>[];

    for (int i = 3; i >= 1; i--) {
      if (currentSectionIndex - i >= 0) {
        sectionsToLoad.add(currentSectionIndex - i);
      }
    }
    for (int i = 1; i <= 3; i++) {
      if (currentSectionIndex + i < totalSections) {
        sectionsToLoad.add(currentSectionIndex + i);
      }
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
    required double textContainerHeight,
    int startFrom = 0,
  }) {
    if (_isBackgroundPaginationRunning) return;
    _isBackgroundPaginationRunning = true;

    Future.microtask(() {
      _paginateNextSection(
        book: book,
        fontSize: fontSize,
        lineHeight: lineHeight,
        screenSize: screenSize,
        textContainerHeight: textContainerHeight,
        prioritySection: startFrom,
      );
    });
  }

  Future<void> _paginateNextSection({
    required Book book,
    required double fontSize,
    required double lineHeight,
    required Size screenSize,
    required double textContainerHeight,
    int? prioritySection,
  }) async {
    if (!_isBackgroundPaginationRunning) return;

    int? nextSection;

    if (prioritySection != null) {
      for (int offset in [1, -1, 2, -2, 3, -3, 4, -4, 5, -5]) {
        final candidate = prioritySection + offset;
        if (candidate >= 0 &&
            candidate < book.sections.length &&
            !_paginatedSections.contains(candidate) &&
            !_paginatingNow.contains(candidate)) {
          nextSection = candidate;
          break;
        }
      }
    }

    if (nextSection == null) {
      for (int i = 0; i < book.sections.length; i++) {
        if (!_paginatedSections.contains(i) && !_paginatingNow.contains(i)) {
          nextSection = i;
          break;
        }
      }
    }

    if (nextSection != null) {
      await _paginateSectionFast(
        book: book,
        sectionIndex: nextSection,
        fontSize: fontSize,
        lineHeight: lineHeight,
        screenSize: screenSize,
        textContainerHeight: textContainerHeight,
        background: true,
      );

      await Future.delayed(const Duration(milliseconds: 30));

      _paginateNextSection(
        book: book,
        fontSize: fontSize,
        lineHeight: lineHeight,
        screenSize: screenSize,
        textContainerHeight: textContainerHeight,
        prioritySection: prioritySection,
      );
    } else {
      print('✅ Background pagination complete! Total sections: ${_paginatedSections.length}');
      _isBackgroundPaginationRunning = false;
      await _saveDirtySections();
      onBackgroundPaginationComplete?.call();
    }
  }

  Future<void> _paginateSectionFast({
    required Book book,
    required int sectionIndex,
    required double fontSize,
    required double lineHeight,
    required Size screenSize,
    required double textContainerHeight,
    bool background = false,
  }) async {
    if (_paginatedSections.contains(sectionIndex) || _paginatingNow.contains(sectionIndex)) {
      return;
    }

    _paginatingNow.add(sectionIndex);

    final section = book.sections[sectionIndex];
    final paragraphs = section.paragraphs;
    final padding = const EdgeInsets.all(24.0);
    final availableHeight = textContainerHeight;
    final availableWidth = screenSize.width - padding.horizontal;

    final textStyle = TextStyle(fontSize: fontSize, height: lineHeight);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    final avgCharWidth = fontSize * 0.55;
    final charsPerLine = (availableWidth / avgCharWidth).floor();
    final lineHeightPx = fontSize * lineHeight;
    final linesPerPage = (availableHeight / lineHeightPx).floor();
    final estimatedCharsPerPage = charsPerLine * linesPerPage;

    List<PageData> pages = [];
    List<WordToken> currentPageTokens = [];
    int currentEstimatedChars = 0;

    final allTokens = <WordToken>[];
    for (final paragraph in paragraphs) {
      allTokens.addAll(TextTokenizer.tokenize(paragraph + '\n\u00A0\u00A0\u00A0'));
    }

    int tokenIndex = 0;
    int lastCheckIndex = 0;

    while (tokenIndex < allTokens.length) {
      final token = allTokens[tokenIndex];
      currentPageTokens.add(token);
      currentEstimatedChars += token.text.length;
      tokenIndex++;

      if (currentEstimatedChars >= estimatedCharsPerPage * 0.85) {
        if (tokenIndex - lastCheckIndex >= 10 || currentEstimatedChars >= estimatedCharsPerPage) {
          final currentText = currentPageTokens.map((t) => t.text).join();
          textPainter.text = TextSpan(text: currentText, style: textStyle);
          textPainter.layout(maxWidth: availableWidth);
          lastCheckIndex = tokenIndex;

          if (textPainter.height > availableHeight) {
            currentPageTokens.removeLast();
            tokenIndex--;

            if (currentPageTokens.isNotEmpty) {
              pages.add(PageData(
                text: currentPageTokens.map((t) => t.text).join().trim(),
                tokens: List.from(currentPageTokens),
              ));
            }

            currentPageTokens = [];
            currentEstimatedChars = 0;
          }
        }
      }
    }

    if (currentPageTokens.isNotEmpty) {
      pages.add(PageData(
        text: currentPageTokens.map((t) => t.text).join().trim(),
        tokens: List.from(currentPageTokens),
      ));
    }

    _sectionPages[sectionIndex] = pages;
    _paginatedSections.add(sectionIndex);
    _paginatingNow.remove(sectionIndex);

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

      _dirtySections.add(sectionIndex);

      if (_dirtySections.length >= 10 ||
          (_lastSaveTime != null &&
              DateTime.now().difference(_lastSaveTime!) > const Duration(seconds: 15))) {
        await _saveDirtySections();
      }
    }

    if (!background) {
      onPaginationUpdate?.call();
    }
  }

  Future<void> _saveDirtySections() async {
    if (_dirtySections.isEmpty || _currentCache == null) return;

    print('💾 Saving ${_dirtySections.length} sections to cache...');
    print('🔑 Cache key: ${_currentCache!.bookFilePath}');

    final cacheKey = _currentCache!.bookFilePath;
    await _cacheBox?.put(cacheKey, _currentCache!);

    await _cacheBox?.flush();

    _dirtySections.clear();
    _lastSaveTime = DateTime.now();

    print('✅ Cache saved and flushed to disk');
    print('📦 All cache keys now: ${_cacheBox?.keys.toList()}');
  }

  bool isSectionLoaded(int sectionIndex) {
    return _paginatedSections.contains(sectionIndex);
  }

  List<PageData> getSectionPages(int sectionIndex) {
    return _sectionPages[sectionIndex] ?? [PageData(text: '', tokens: [])];
  }

  Future<void> saveCacheToHive() async {
    await _saveDirtySections();
  }

  void clear() {
    _sectionPages.clear();
    _paginatedSections.clear();
    _paginatingNow.clear();
    _currentCache = null;
    _isBackgroundPaginationRunning = false;
    _dirtySections.clear();
  }

  Future<void> dispose() async {
    _isBackgroundPaginationRunning = false;
    await saveCacheToHive();
  }
}