// services/pagination.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:chitalka/models/book.dart';
import 'package:chitalka/models/page_data.dart';
import 'package:chitalka/models/word_token.dart';
import 'package:chitalka/core/tokenizer.dart';

class PaginationService extends ChangeNotifier {
  static const int MAX_CACHED_SECTIONS = 7;

  final Map<int, List<PageData>> _sectionPages = {};
  final Map<int, Completer<void>> _paginationCompleters = {};
  final List<int> _accessOrder = <int>[];
  final Set<int> _paginatingNow = {};
  final Map<String, int> _estimationCache = {};

  final TextPainter _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.justify,
  );

  void _touchSection(int sectionIndex) {
    _accessOrder.remove(sectionIndex);
    _accessOrder.add(sectionIndex);

    while (_accessOrder.length > MAX_CACHED_SECTIONS) {
      final lru = _accessOrder.removeAt(0);
      _sectionPages.remove(lru);
      _paginationCompleters.remove(lru);
      print('Evicted section $lru from RAM');
    }
  }

  double _measureTextHeightWithLayout(
      List<WordToken> tokens,
      TextStyle textStyle,
      double maxWidth,
      ) {
    if (tokens.isEmpty) return 0;

    final spans = tokens.map((token) {
      return TextSpan(text: token.text, style: textStyle);
    }).toList();

    _textPainter
      ..text = TextSpan(children: spans, style: textStyle)
      ..textAlign = TextAlign.justify
      ..layout(maxWidth: maxWidth);

    return _textPainter.height;
  }

  Future<void> _paginateSectionIncremental({
    required Book book,
    required int sectionIndex,
    required double fontSize,
    required double lineHeight,
    required Size screenSize,
    required double textContainerHeight,
  }) async {
    final section = book.sections[sectionIndex];
    final padding = const EdgeInsets.symmetric(horizontal: 24.0);
    final availableWidth = screenSize.width - padding.horizontal;
    final availableHeight = textContainerHeight;
    final textStyle = TextStyle(fontSize: fontSize, height: lineHeight);

    final allTokens = _tokenizeSectionSync(section.paragraphs);
    if (allTokens.isEmpty) {
      _sectionPages[sectionIndex] = [];
      notifyListeners();
      return;
    }

    final estimatedTokensPerPage = _estimateTokensPerPage(
      textStyle: textStyle,
      availableWidth: availableWidth,
      availableHeight: availableHeight,
      sampleTokens: allTokens,
    );

    print('Estimated tokens per page: $estimatedTokensPerPage');

    final List<PageData> finalPages = [];
    int currentIndex = 0;

    while (currentIndex < allTokens.length) {
      await Future.delayed(Duration.zero);

      final remainingTokens = allTokens.sublist(currentIndex);

      final pageTokens = _fitTokensToPage(
        tokens: remainingTokens,
        textStyle: textStyle,
        availableWidth: availableWidth,
        availableHeight: availableHeight,
        estimatedCount: estimatedTokensPerPage,
      );

      if (pageTokens.isEmpty) {
        finalPages.add(_createPageData([remainingTokens.first]));
        currentIndex++;
      } else {
        finalPages.add(_createPageData(pageTokens));
        currentIndex += pageTokens.length;
      }

      if (finalPages.length % 3 == 0) {
        _sectionPages[sectionIndex] = List.unmodifiable(finalPages);
        notifyListeners();
      }
    }

    _sectionPages[sectionIndex] = List.unmodifiable(finalPages);
    notifyListeners();
  }

  List<WordToken> _fitTokensToPage({
    required List<WordToken> tokens,
    required TextStyle textStyle,
    required double availableWidth,
    required double availableHeight,
    required int estimatedCount,
  }) {
    if (tokens.isEmpty) return [];

    int left = 1;
    int right = tokens.length;
    int bestFit = 0;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final testTokens = tokens.sublist(0, mid);
      final height = _measureTextHeightWithLayout(
        testTokens,
        textStyle,
        availableWidth,
      );

      if (height <= availableHeight) {
        bestFit = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    if (bestFit == 0) return [];

    int finalCount = bestFit;
    for (int i = bestFit + 1; i <= min(bestFit + 20, tokens.length); i++) {
      final testTokens = tokens.sublist(0, i);
      final height = _measureTextHeightWithLayout(
        testTokens,
        textStyle,
        availableWidth,
      );

      if (height <= availableHeight) {
        finalCount = i;
      } else {
        break;
      }
    }

    return tokens.sublist(0, finalCount);
  }

  int _estimateTokensPerPage({
    required TextStyle textStyle,
    required double availableWidth,
    required double availableHeight,
    required List<WordToken> sampleTokens,
  }) {
    if (sampleTokens.isEmpty) return 150;

    final sampleSize = min(800, sampleTokens.length);
    final startIndex = max(0, (sampleTokens.length - sampleSize) ~/ 2);
    final sample = sampleTokens.sublist(startIndex, startIndex + sampleSize);

    final sampleHeight = _measureTextHeightWithLayout(
      sample,
      textStyle,
      availableWidth,
    );

    if (sampleHeight <= 0) return 150;

    final ratio = availableHeight / sampleHeight;
    final estimated = (sample.length * ratio).floor();

    return max(80, (estimated * 0.85).floor());
  }

  PageData _createPageData(List<WordToken> tokens) {
    if (tokens.isEmpty) {
      return PageData(text: '', tokens: List.unmodifiable([]));
    }

    final paddingTokens = List.generate(
      100,
          (i) => WordToken(text: '\u200B', word: '', startOffset: -1),
    );

    final finalTokens = [...tokens, ...paddingTokens];

    return PageData(
      text: finalTokens.map((t) => t.text).join(),
      tokens: List.unmodifiable(finalTokens),
    );
  }

  List<WordToken> _tokenizeSectionSync(List<String> paragraphs) {
    final tokens = <WordToken>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      tokens.addAll(TextTokenizer.tokenize(p));

      if (i < paragraphs.length - 1) {
        tokens.addAll(TextTokenizer.tokenize('\n'));
      }
    }
    return tokens;
  }

  Future<void> paginateSection({
    required Book book,
    required int sectionIndex,
    required double fontSize,
    required double lineHeight,
    required Size screenSize,
    required double textContainerHeight,
  }) async {
    if (_sectionPages.containsKey(sectionIndex)) {
      _touchSection(sectionIndex);
      return;
    }

    if (_paginatingNow.contains(sectionIndex)) {
      await _paginationCompleters[sectionIndex]?.future;
      return;
    }

    _paginatingNow.add(sectionIndex);
    _paginationCompleters[sectionIndex] = Completer<void>();

    try {
      await _paginateSectionIncremental(
        book: book,
        sectionIndex: sectionIndex,
        fontSize: fontSize,
        lineHeight: lineHeight,
        screenSize: screenSize,
        textContainerHeight: textContainerHeight,
      );

      _touchSection(sectionIndex);
      _paginationCompleters[sectionIndex]?.complete();
    } catch (e) {
      _paginationCompleters[sectionIndex]?.completeError(e);
      rethrow;
    } finally {
      _paginatingNow.remove(sectionIndex);
    }
  }

  List<PageData> getSectionPages(int sectionIndex) {
    final pages = _sectionPages[sectionIndex];
    if (pages != null && pages.isNotEmpty) {
      _touchSection(sectionIndex);
      return pages;
    }
    return [];
  }

  bool isSectionReady(int sectionIndex) {
    return _sectionPages.containsKey(sectionIndex) &&
        _sectionPages[sectionIndex]!.isNotEmpty;
  }

  bool isSectionPaginating(int sectionIndex) {
    return _paginatingNow.contains(sectionIndex);
  }

  int getSectionPageCount(int sectionIndex) {
    return _sectionPages[sectionIndex]?.length ?? 0;
  }

  Future<int> estimateTotalPages({
    required Book book,
    required double fontSize,
    required double lineHeight,
    required double availableWidth,
    required double availableHeight,
  }) async {
    final key = '${fontSize.round()}|${availableWidth.round()}|${availableHeight.round()}';
    if (_estimationCache.containsKey(key)) return _estimationCache[key]!;

    int totalChars = 0;
    for (final section in book.sections) {
      for (final p in section.paragraphs) {
        totalChars += p.length;
      }
    }

    final textStyle = TextStyle(fontSize: fontSize, height: lineHeight);

    final charsPerLine = (availableWidth / (fontSize * 0.5)).floor();
    final lineHeightPx = fontSize * lineHeight;
    final linesPerPage = (availableHeight / lineHeightPx).floor();
    final charsPerPage = charsPerLine * linesPerPage;

    final estimated = (totalChars / charsPerPage * 1.1).ceil();
    _estimationCache[key] = estimated;
    return estimated;
  }

  void clear() {
    _sectionPages.clear();
    _accessOrder.clear();
    _paginatingNow.clear();
    _paginationCompleters.clear();
    _estimationCache.clear();
  }

  @override
  void dispose() {
    _textPainter.dispose();
    clear();
    super.dispose();
  }
}