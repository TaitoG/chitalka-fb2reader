// services/custom_renderer.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'theme_service.dart';

class LayoutWord {
  final String text;
  final String cleanWord;
  final Offset position;
  final Size size;
  final int documentOffset;
  final bool isHeader;

  LayoutWord({
    required this.text,
    required this.cleanWord,
    required this.position,
    required this.size,
    required this.documentOffset,
    this.isHeader = false,
  });

  Rect get bounds => position & size;
}

class LayoutLine {
  final List<LayoutWord> words;
  final double y;
  final double height;

  LayoutLine({
    required this.words,
    required this.y,
    required this.height,
  });
}

class RenderCustomText extends RenderBox {
  String _text;
  TextStyle _textStyle;
  double _scrollOffset;
  int? _selectedWordOffset;
  Set<String> _bookmarkedWords;

  AppTheme _theme = AppTheme.light;
  AppTheme get theme => _theme;
  set theme(AppTheme value) {
    if (_theme == value) return;
    _theme = value;
    markNeedsPaint();
  }

  List<LayoutLine> _lines = [];
  List<LayoutLine> get lines => _lines;
  double _lastLayoutWidth = 0;
  double _lastViewportHeight = 0;
  int _layoutChunkSize = 5000;
  int _currentLayoutEnd = 0;

  TextAlign _textAlign = TextAlign.left;
  TextAlign get textAlign => _textAlign;
  set textAlign(TextAlign value) {
    if (_textAlign == value) return;
    _textAlign = value;
    _lines.clear();
    _currentLayoutEnd = 0;
    markNeedsLayout();
  }

  final TextPainter _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  RenderCustomText({
    required String text,
    required TextStyle textStyle,
    double scrollOffset = 0,
    int? selectedWordOffset,
    Set<String> bookmarkedWords = const {},
  })  : _text = text,
        _textStyle = textStyle,
        _scrollOffset = scrollOffset,
        _selectedWordOffset = selectedWordOffset,
        _bookmarkedWords = bookmarkedWords;

  String get text => _text;
  set text(String value) {
    if (_text == value) return;
    _text = value;
    _lines.clear();
    _currentLayoutEnd = 0;
    markNeedsLayout();
  }

  TextStyle get textStyle => _textStyle;
  set textStyle(TextStyle value) {
    if (_textStyle == value) return;
    _textStyle = value;
    _lines.clear();
    _currentLayoutEnd = 0;
    markNeedsLayout();
  }

  double get scrollOffset => _scrollOffset;
  set scrollOffset(double value) {
    if (_scrollOffset == value) return;

    final needsMoreLayout = _needsLayoutForScroll(value);
    _scrollOffset = value.clamp(0.0, max(0.0, totalHeight - size.height));

    if (needsMoreLayout) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  void setViewportHeight(double height) {
    if (_lastViewportHeight != height) {
      _lastViewportHeight = height;
      if (_lines.isNotEmpty) {
        _lines.clear();
        _currentLayoutEnd = 0;
        markNeedsLayout();
      }
    }
  }

  double getAlignedScrollOffset(
      double currentOffset,
      double viewportHeight, {
        bool forward = true,
      }) {
    if (_lines.isEmpty) return currentOffset;

    final targetY = forward ? currentOffset + viewportHeight : currentOffset - viewportHeight;
    LayoutLine? bestLine;
    double bestDelta = double.infinity;

    for (final line in _lines) {
      final delta = (line.y - targetY).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestLine = line;
      }
    }

    if (bestLine == null) return currentOffset;

    return bestLine.y.clamp(0.0, max(0.0, totalHeight - viewportHeight));
  }

  bool _needsLayoutForScroll(double newScrollOffset) {
    if (_lines.isEmpty) return true;
    final lastLine = _lines.last;
    final lastY = lastLine.y + lastLine.height;
    return newScrollOffset + size.height * 2 > lastY && _currentLayoutEnd < _text.length;
  }

  int? get selectedWordOffset => _selectedWordOffset;
  set selectedWordOffset(int? value) {
    if (_selectedWordOffset == value) return;
    _selectedWordOffset = value;
    markNeedsPaint();
  }

  Set<String> get bookmarkedWords => _bookmarkedWords;
  set bookmarkedWords(Set<String> value) {
    if (_bookmarkedWords == value) return;
    _bookmarkedWords = value;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    if (constraints.maxWidth == 0 || constraints.maxHeight == 0) {
      size = Size.zero;
      return;
    }

    size = Size(constraints.maxWidth, constraints.maxHeight);

    // Принудительно вёрстаем до scrollOffset
    if (_scrollOffset > 0 && _needsLayoutForScroll(_scrollOffset)) {
      layoutUntilScrollOffset(_scrollOffset, size.height);
    }

    if (_lines.isEmpty ||
        _lastLayoutWidth != constraints.maxWidth ||
        _needsLayoutForScroll(_scrollOffset)) {
      _performIncrementalLayout(constraints.maxWidth);
      _lastLayoutWidth = constraints.maxWidth;
    }
  }

  void layoutUntilScrollOffset(double targetScrollOffset, double viewportHeight) {
    while (_needsLayoutForScroll(targetScrollOffset) && _currentLayoutEnd < _text.length) {
      _performIncrementalLayout(constraints.maxWidth);
    }
  }
  // -----------------------------------------------------------------
  //  JUSTIFY HELPERS
  // -----------------------------------------------------------------
  void applyJustifyIfNeeded(
      List<LayoutWord> words, {
        required bool isParagraphEnd,
        required bool isLastChunk,
        required bool forceNoJustify,
      }) {
    if (_textAlign != TextAlign.justify || words.isEmpty) return;
    if (isParagraphEnd || forceNoJustify) return;
    if (isLastChunk && _currentLayoutEnd >= _text.length) return;

    final gapIndices = <int>[];
    double totalWidth = 0.0;

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      totalWidth += w.size.width;
      final hasWhitespace = RegExp(r'\s').hasMatch(w.text);
      final hasLetter = RegExp(r'[\wа-яА-ЯёЁ]').hasMatch(w.text);
      if (hasWhitespace && !hasLetter) gapIndices.add(i);
    }

    if (gapIndices.isEmpty || totalWidth >= constraints.maxWidth - 0.01) return;

    final extraPerGap = (constraints.maxWidth - totalWidth) / gapIndices.length;
    double x = 0.0;
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final newWidth = gapIndices.contains(i) ? w.size.width + extraPerGap : w.size.width;
      words[i] = LayoutWord(
        text: w.text,
        cleanWord: w.cleanWord,
        position: Offset(x, w.position.dy),
        size: Size(newWidth, w.size.height),
        documentOffset: w.documentOffset,
        isHeader: w.isHeader,
      );
      x += newWidth;
    }
  }

  // -----------------------------------------------------------------
  //  INCREMENTAL LAYOUT
  // -----------------------------------------------------------------
  void _performIncrementalLayout(double maxWidth) {
    if (_text.isEmpty) return;

    if (_lines.isEmpty) _currentLayoutEnd = 0;

    final chunkSize = _layoutChunkSize;
    int startOffset = _currentLayoutEnd;
    int endOffset = min(_currentLayoutEnd + chunkSize, _text.length);

    if (endOffset < _text.length) {
      int lastNewline = _text.lastIndexOf('\n', endOffset);
      if (lastNewline > startOffset) {
        endOffset = lastNewline + 1;
      } else {
        final sentenceEnd = RegExp(r'[.!?]\s').firstMatch(_text.substring(startOffset, endOffset));
        if (sentenceEnd != null) {
          endOffset = startOffset + sentenceEnd.end;
        }
      }
    }

    if (startOffset >= _text.length) return;

    final chunk = _text.substring(startOffset, endOffset);
    final tokens = _tokenize(chunk);
    double currentY = _lines.isEmpty ? 0 : (_lines.last.y + _lines.last.height);
    double currentX = 0;
    List<LayoutWord> currentLineWords = [];



    final defaultLineHeight = _textStyle.fontSize! * (_textStyle.height ?? 1.4);
    int documentOffset = startOffset;
    bool isInsideChapter = false;

    for (final token in tokens) {
      // ------------------- HEADER -------------------
      if (token.isHeader) {
        if (currentLineWords.isNotEmpty) {
          applyJustifyIfNeeded(
            currentLineWords,
            isParagraphEnd: true,
            isLastChunk: false,
            forceNoJustify: false,
          );
          _lines.add(LayoutLine(
              words: List.from(currentLineWords),
              y: currentY,
              height: defaultLineHeight));
          currentLineWords.clear();
          currentY += defaultLineHeight;
          currentX = 0;
        }

        if (_lines.isNotEmpty && _lastViewportHeight > 0) {
          final currentPage = (currentY / _lastViewportHeight).floor();
          final nextPageStart = (currentPage + 1) * _lastViewportHeight;

          if (currentY > currentPage * _lastViewportHeight + defaultLineHeight) {
            currentY = nextPageStart;
          }
        }

        final headerStyle = _textStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: _textStyle.fontSize! * 1.25,
        );
        _textPainter.text = TextSpan(text: token.headerTitle, style: headerStyle);
        _textPainter.layout();

        final headerHeight = _textPainter.size.height;
        final headerWord = LayoutWord(
          text: token.text,
          cleanWord: '',
          position: Offset(0, currentY),
          size: _textPainter.size,
          documentOffset: documentOffset,
          isHeader: true,
        );

        _lines.add(LayoutLine(words: [headerWord], y: currentY, height: headerHeight));

        currentY += headerHeight + (defaultLineHeight * 0.1);
        currentX = 0;
        documentOffset += token.text.length;

        isInsideChapter = true;
        continue;
      }

      // ------------------- NORMAL TEXT -------------------
      _textPainter.text = TextSpan(text: token.text, style: _textStyle);
      _textPainter.layout();
      final tokenWidth = _textPainter.size.width;

      // Line break because of width
      if (currentX + tokenWidth > maxWidth && currentLineWords.isNotEmpty) {
        final isLastLineOfChapter = isInsideChapter && token.text.trim().isEmpty;
        applyJustifyIfNeeded(
          currentLineWords,
          isParagraphEnd: token.text.contains('\n'),
          isLastChunk: endOffset >= _text.length,
          forceNoJustify: isLastLineOfChapter,
        );

        _lines.add(LayoutLine(
            words: List.from(currentLineWords),
            y: currentY,
            height: defaultLineHeight));
        currentLineWords.clear();
        currentY += defaultLineHeight;
        currentX = 0;
      }

      currentLineWords.add(LayoutWord(
        text: token.text,
        cleanWord: token.cleanWord,
        position: Offset(currentX, currentY),
        size: Size(tokenWidth, _textPainter.size.height),
        documentOffset: documentOffset,
      ));

      currentX += tokenWidth;
      documentOffset += token.text.length;

      // Explicit paragraph break
      if (token.text.contains('\n')) {
        final isLastLineOfChapter = isInsideChapter && token.text.contains('\n\n');
        applyJustifyIfNeeded(
          currentLineWords,
          isParagraphEnd: true,
          isLastChunk: endOffset >= _text.length,
          forceNoJustify: isLastLineOfChapter,
        );

        _lines.add(LayoutLine(
            words: List.from(currentLineWords),
            y: currentY,
            height: defaultLineHeight));
        currentLineWords.clear();
        currentY += defaultLineHeight;
        currentX = 0;
      }
    }

    // Flush remaining words
    if (currentLineWords.isNotEmpty) {
      final isLastLineOfChapter =
          isInsideChapter && currentLineWords.last.text.contains('\n');
      applyJustifyIfNeeded(
        currentLineWords,
        isParagraphEnd: currentLineWords.last.text.contains('\n'),
        isLastChunk: endOffset >= _text.length,
        forceNoJustify: isLastLineOfChapter,
      );

      _lines.add(LayoutLine(
          words: List.from(currentLineWords),
          y: currentY,
          height: defaultLineHeight));
    }

    _currentLayoutEnd = endOffset;
  }

  double _getLastLineEndX() {
    if (_lines.isEmpty || _lines.last.words.isEmpty) return 0;
    final lastWord = _lines.last.words.last;
    return lastWord.position.dx + lastWord.size.width;
  }

  // -----------------------------------------------------------------
  //  TOKENIZATION
  // -----------------------------------------------------------------
  List<_Token> _tokenize(String text) {
    final tokens = <_Token>[];
    final headerPattern = RegExp(r'§([^§]+)§');
    int lastEnd = 0;

    for (final match in headerPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        final prefix = text.substring(lastEnd, match.start);
        tokens.addAll(_splitIntoTokens(prefix));
      }

      final title = match.group(1)!;
      tokens.add(_Token(
        text: '$title\n',
        cleanWord: '',
        isHeader: true,
        headerTitle: title,
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      tokens.addAll(_splitIntoTokens(text.substring(lastEnd)));
    }
    return tokens;
  }

  List<_Token> _splitIntoTokens(String text) {
    final tokens = <_Token>[];
    final pattern = RegExp(
      r"""[a-zA-Zа-яА-ЯёЁ0-9'’\-]+|[^\sa-zA-Zа-яА-ЯёЁ0-9'’\-]+|\s+""",
      unicode: true,
    );

    for (final match in pattern.allMatches(text)) {
      final word = match.group(0)!;
      if (RegExp(r'\s').hasMatch(word)) {
        tokens.add(_Token(text: word, cleanWord: ''));
        continue;
      }
      final clean = word
          .replaceAll(RegExp(r'[^\wа-яА-ЯёЁ]'), '')
          .toLowerCase();
      tokens.add(_Token(text: word, cleanWord: clean));
    }
    return tokens;
  }

  // -----------------------------------------------------------------
  //  PAINT
  // -----------------------------------------------------------------
  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.clipRect(offset & size);

    final highlightPaint = Paint()..color = ThemeService.getHighlightColor(_theme);
    final headerBgPaint = Paint()..color = ThemeService.getHeaderBgColor(_theme);

    for (final line in _lines) {
      final lineScreenY = line.y - _scrollOffset;
      if (lineScreenY + line.height < -50 || lineScreenY > size.height + 50) continue;

      for (final word in line.words) {
        final wordScreenPos = Offset(offset.dx + word.position.dx, offset.dy + lineScreenY);

        // Header background
        if (word.isHeader) {
          canvas.drawRect(wordScreenPos & word.size, headerBgPaint);
        }

        // Selection
        if (_selectedWordOffset != null && word.documentOffset == _selectedWordOffset) {
          canvas.drawRect(wordScreenPos & word.size, highlightPaint);
        }

        // Bookmark underline
        if (word.cleanWord.isNotEmpty &&
            _bookmarkedWords.contains(word.cleanWord.toLowerCase())) {
          final y = wordScreenPos.dy + word.size.height - 2;
          final underlinePaint = Paint()
            ..color = Colors.blue.withOpacity(0.5)
            ..strokeWidth = 1.5;
          canvas.drawLine(
            Offset(wordScreenPos.dx, y),
            Offset(wordScreenPos.dx + word.size.width, y),
            underlinePaint,
          );
        }

        // Paint text
        _textPainter.text = TextSpan(
          text: word.text,
          style: word.isHeader
              ? _textStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: _textStyle.fontSize! * 1.25,
          )
              : _textStyle,
        );
        _textPainter.layout();
        _textPainter.paint(canvas, wordScreenPos);
      }
    }
  }

  @override
  bool hitTestSelf(Offset position) => true;

  LayoutWord? findWordAt(Offset localPosition) {
    final documentY = localPosition.dy + _scrollOffset;
    for (final line in _lines) {
      if (documentY < line.y || documentY > line.y + line.height) continue;
      for (final word in line.words) {
        final bounds = word.bounds;
        if (localPosition.dx >= bounds.left &&
            localPosition.dx <= bounds.right &&
            documentY >= bounds.top &&
            documentY <= bounds.bottom) {
          return word;
        }
      }
    }
    return null;
  }

  double get totalHeight {
    if (_lines.isEmpty) return _estimateHeight();
    final lastLine = _lines.last;
    final currentHeight = lastLine.y + lastLine.height;
    if (_currentLayoutEnd >= _text.length) return currentHeight;

    final remaining = _text.length - _currentLayoutEnd;
    final avg = _currentLayoutEnd > 0 ? _currentLayoutEnd / _lines.length : 50;
    final estimatedLines = remaining / avg;
    final lineHeight = _textStyle.fontSize! * (_textStyle.height ?? 1.4);
    return currentHeight + estimatedLines * lineHeight;
  }

  double _estimateHeight() {
    final charsPerLine =
    (_lastLayoutWidth > 0 ? _lastLayoutWidth / (_textStyle.fontSize! * 0.55) : 50).floor();
    final lines = (_text.length / charsPerLine).ceil();
    final lineHeight = _textStyle.fontSize! * (_textStyle.height ?? 1.4);
    return lines * lineHeight;
  }

  @override
  void dispose() {
    _textPainter.dispose();
    super.dispose();
  }
}

// -----------------------------------------------------------------
//  TOKEN
// -----------------------------------------------------------------
class _Token {
  final String text;
  final String cleanWord;
  final bool isHeader;
  final String? headerTitle;

  _Token({
    required this.text,
    this.cleanWord = '',
    this.isHeader = false,
    this.headerTitle,
  });
}

// -----------------------------------------------------------------
//  WIDGET
// -----------------------------------------------------------------
class CustomTextWidget extends LeafRenderObjectWidget {
  final String text;
  final TextStyle textStyle;
  final double scrollOffset;
  final int? selectedWordOffset;
  final Set<String> bookmarkedWords;
  final TextAlign textAlign;
  final double viewportHeight;

  const CustomTextWidget({
    Key? key,
    required this.text,
    required this.textStyle,
    this.scrollOffset = 0,
    this.selectedWordOffset,
    this.bookmarkedWords = const {},
    this.textAlign = TextAlign.left,
    this.viewportHeight = 0,
  }) : super(key: key);

  @override
  RenderCustomText createRenderObject(BuildContext context) {
    return RenderCustomText(
      text: text,
      textStyle: textStyle,
      scrollOffset: scrollOffset,
      selectedWordOffset: selectedWordOffset,
      bookmarkedWords: bookmarkedWords,
    )..textAlign = textAlign
      ..setViewportHeight(viewportHeight);
  }

  @override
  void updateRenderObject(BuildContext context, RenderCustomText renderObject) {
    renderObject
      ..text = text
      ..textStyle = textStyle
      ..scrollOffset = scrollOffset
      ..selectedWordOffset = selectedWordOffset
      ..bookmarkedWords = bookmarkedWords
      ..textAlign = textAlign
      ..setViewportHeight(viewportHeight);
  }
}