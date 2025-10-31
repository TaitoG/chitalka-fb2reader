// services/pagination.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chitalka/models/book.dart';
import 'package:chitalka/models/page_data.dart';
import 'package:chitalka/models/word_token.dart';
import 'package:chitalka/core/tokenizer.dart';

class PaginationService extends ChangeNotifier {
  static const int MAX_CACHED_SECTIONS = 7;
  static const int TOKENS_PER_YIELD = 50;

  final Map<int, List<PageData>> _sectionPages = {};
  final Map<int, Completer<void>> _paginationCompleters = {};
  final List<int> _accessOrder = <int>[];
  final Set<int> _paginatingNow = {};
  final Map<String, int> _estimationCache = {};

  final TextPainter _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.justify,
  );

  final Map<double, double> _avgCharWidthCache = {};

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

  double _measureAverageCharWidth(TextStyle textStyle) {
    final fontSize = textStyle.fontSize ?? 14.0;

    if (_avgCharWidthCache.containsKey(fontSize)) {
      return _avgCharWidthCache[fontSize]!;
    }

    const sampleText = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмнопрстуфхцчшщъыьэюя';
    _textPainter
      ..text = TextSpan(text: sampleText, style: textStyle)
      ..layout();

    final avgWidth = _textPainter.width / sampleText.length;
    _avgCharWidthCache[fontSize] = avgWidth;

    return avgWidth;
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
    final padding = const EdgeInsets.all(24.0);
    final availableHeight = textContainerHeight;
    final availableWidth = screenSize.width - padding.horizontal;
    final textStyle = TextStyle(fontSize: fontSize, height: lineHeight);

    final avgCharWidth = _measureAverageCharWidth(textStyle);
    final charsPerLine = (availableWidth / avgCharWidth).floor();
    final lineHeightPx = fontSize * lineHeight;
    final linesPerPage = (availableHeight / lineHeightPx).floor();
    final estimatedCharsPerPage = charsPerLine * linesPerPage;

    final allTokens = _tokenizeSectionSync(section.paragraphs);

    List<PageData> pages = [];
    List<WordToken> currentPageTokens = [];
    int currentEstimatedChars = 0;
    int tokensSinceYield = 0;

    for (int tokenIndex = 0; tokenIndex < allTokens.length; tokenIndex++) {
      final token = allTokens[tokenIndex];
      currentPageTokens.add(token);
      currentEstimatedChars += token.text.length;
      tokensSinceYield++;

      if (tokensSinceYield >= TOKENS_PER_YIELD) {
        await Future.delayed(Duration.zero);
        tokensSinceYield = 0;
      }

      if (currentEstimatedChars >= estimatedCharsPerPage * 0.85) {
        final currentText = currentPageTokens.map((t) => t.text).join();
        _textPainter
          ..text = TextSpan(text: currentText, style: textStyle)
          ..layout(maxWidth: availableWidth);

        if (_textPainter.height > availableHeight) {
          int left = 0;
          int right = currentPageTokens.length - 1;
          int bestFit = right;

          while (left <= right) {
            final mid = (left + right) ~/ 2;
            final testText = currentPageTokens.sublist(0, mid + 1).map((t) => t.text).join();
            _textPainter
              ..text = TextSpan(text: testText, style: textStyle)
              ..layout(maxWidth: availableWidth);

            if (_textPainter.height <= availableHeight) {
              bestFit = mid;
              left = mid + 1;
            } else {
              right = mid - 1;
            }
          }

          final pageTokens = currentPageTokens.sublist(0, bestFit + 1);
          final remainingTokens = currentPageTokens.sublist(bestFit + 1);

          final indentTokens = TextTokenizer.tokenize('\u200B' * 50);
          pageTokens.addAll(indentTokens);

          if (pageTokens.isNotEmpty) {
            final page = PageData(
              text: pageTokens.map((t) => t.text).join().trim(),
              tokens: List.unmodifiable(pageTokens),
            );
            pages.add(page);

            _sectionPages[sectionIndex] = List.from(pages);
            notifyListeners();

            await Future.delayed(Duration.zero);
          }

          currentPageTokens = remainingTokens;
          currentEstimatedChars = remainingTokens.fold(0, (sum, t) => sum + t.text.length);
        }
      }
    }

    if (currentPageTokens.isNotEmpty) {
      pages.add(PageData(
        text: currentPageTokens.map((t) => t.text).join().trim(),
        tokens: List.unmodifiable(currentPageTokens),
      ));
      _sectionPages[sectionIndex] = pages;
      notifyListeners();
    }
  }

  List<WordToken> _tokenizeSectionSync(List<String> paragraphs) {
    final tokens = <WordToken>[];
    for (final p in paragraphs) {
      tokens.addAll(TextTokenizer.tokenize(p + '\n   '));
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
      totalChars += 2;
    }

    final textStyle = TextStyle(fontSize: fontSize, height: lineHeight);
    final avgCharWidth = _measureAverageCharWidth(textStyle);
    final charsPerLine = (availableWidth / avgCharWidth).floor();
    final lineHeightPx = fontSize * lineHeight;
    final linesPerPage = (availableHeight / lineHeightPx).floor();
    final charsPerPage = charsPerLine * linesPerPage;

    final estimated = (totalChars / charsPerPage * 1.05).ceil();
    _estimationCache[key] = estimated;
    return estimated;
  }

  void clear() {
    _sectionPages.clear();
    _accessOrder.clear();
    _paginatingNow.clear();
    _paginationCompleters.clear();
    _estimationCache.clear();
    _avgCharWidthCache.clear();
  }

  @override
  void dispose() {
    _textPainter.dispose();
    clear();
    super.dispose();
  }
}